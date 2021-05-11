defmodule Surface.Compiler.AstTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  @constructs %{
    "if" => Surface.Construct.If,
    "for" => Surface.Construct.For,
    "template" => Surface.Construct.Template,
    "slot" => Surface.Construct.Slot
  }

  @directives [
    Surface.Directive.ComponentProps,
    Surface.Directive.Let,
    Surface.Directive.Hook,
    Surface.Directive.Values,
    Surface.Directive.TagAttrs,
    Surface.Directive.Events,
    Surface.Directive.Show,
    Surface.Directive.If,
    Surface.Directive.For,
    Surface.Directive.Debug
  ]

  alias Surface.AST
  alias Surface.Compiler.Helpers
  alias Surface.IOHelper
  alias Surface.Compiler.Parser

  defguardp is_component(context) when context.type in [AST.Component, AST.MacroComponent]
  defguardp is_construct(context) when context.type == Surface.Construct
  defguardp is_subblock(context) when context.type == Surface.Construct.SubBlock
  defguardp is_tag(context) when context.type in [AST.Tag, AST.VoidTag]

  def handle_comment(state, _comment), do: {state, :ignore}

  def handle_literal(state, value) do
    {state, %AST.Literal{value: value}}
  end

  def handle_init(state) do
    Map.put(state, __MODULE__, %{
      modules: [],
      templates: []
    })
  end

  def handle_end(%{__MODULE__ => extras}, children) do
    # the idea here is to return enough information to perform additional validation
    # and inject the required code to add a compile time dependency
    # that might be a bit simpler than injecting AST.Expr statements into the ast itself
    {extras, children}
  end

  def handle_interpolation(state, expression, parse_meta) do
    ast_meta = to_meta(state, parse_meta)

    {state,
     %AST.Interpolation{
       original: expression,
       value: Helpers.interpolation_to_quoted!(expression, ast_meta),
       meta: ast_meta
     }}
  end

  def handle_subblock(state, context, name, attrs, children, _parse_meta) do
    {attributes, directives} = split_attrs_and_directives(attrs)

    if not Enum.empty?(directives) do
      IOHelper.warn(
        "directives are not supported on subblocks and will be ignored",
        context.meta.caller,
        context.meta.line
      )
    end

    {state,
     %Surface.Construct.SubBlock{
       name: name,
       attributes: attributes,
       body: children,
       meta: context.meta
     }}
  end

  def handle_node(state, context, name, attrs, children, _parse_meta) do
    {attributes, directives} = split_attrs_and_directives(attrs)

    ast = create_ast(context.type, name, attributes, directives, children, context)

    extra_info =
      state
      |> Map.get(__MODULE__)
      |> update_extra_info(context, name, ast)

    {Map.put(state, __MODULE__, extra_info), expand_node(ast)}
  end

  defp update_extra_info(extra_info, %{type: AST.Component} = context, _name, _ast) do
    update_in(extra_info.modules, fn modules -> [context.module | modules] end)
  end

  defp create_ast(Surface.Construct, _name, attributes, directives, children, context) do
    [body, sub_blocks] =
      case children do
        [%Surface.Construct.SubBlock{name: :default, body: body} | sub_blocks] ->
          {body, sub_blocks}

        _ ->
          {[], children}
      end

    ast = context.module.process(attributes, body, sub_blocks, context.meta)

    %{ast | directives: directives}
  end

  defp create_ast(AST.MacroComponent, name, attributes, directives, children, context) do
    %AST.MacroComponent{
      name: name,
      module: context.module,
      attributes: attributes,
      directives: directives,
      body: children,
      meta: context.meta
    }
  end

  defp create_ast(AST.Component, _name, attributes, directives, children, context) do
    %AST.Component{
      module: context.module,
      type: component_type(context.module),
      props: attributes,
      directives: directives,
      templates: extract_templates(children),
      meta: context.meta
    }
  end

  defp create_ast(AST.Tag, name, attributes, directives, children, context) do
    %AST.Tag{
      element: name,
      attributes: attributes,
      directives: directives,
      children: children,
      meta: context.meta
    }
  end

  defp create_ast(AST.VoidTag, name, attributes, directives, _children, context) do
    %AST.VoidTag{
      element: name,
      attributes: attributes,
      directives: directives,
      meta: context.meta
    }
  end

  defp extract_templates(_children) do
    %{}
  end

  defp component_type(module) do
    cond do
      Module.open?(module) ->
        Module.get_attribute(module, :component_type, Surface.BaseComponent)

      function_exported?(module, :component_type, 0) ->
        module.component_type()

      true ->
        Surface.BaseComponent
    end
  end

  defp expand_node(%AST.MacroComponent{} = ast) do
    ast.module.expand(ast.attributes, ast.body, ast.meta)
    # TODO: do we want to make it so that macros can be used/returned from
    # a macro expansion?
    # |> recursively_expand()
    |> wrap_in_container(ast.directives, ast.meta)
    |> expand_node()
  end

  defp expand_node(%{directives: [_ | _] = directives} = ast) do
    directives
    |> Enum.sort_by(fn directive ->
      Enum.find_index(@directives, fn module -> module == directive.module end)
    end)
    |> Enum.reduce(ast, fn directive, node ->
      directive.module.process(directive.name, directive.value, directive.meta, node)
    end)
    |> expand_node()
  end

  defp expand_node(ast), do: ast

  defp wrap_in_container(children, directives, meta)

  defp wrap_in_container(children, directives, meta) when is_list(children) do
    %AST.Container{children: children, directives: directives, meta: meta}
  end

  defp wrap_in_container(child, directives, meta) do
    wrap_in_container([child], directives, meta)
  end

  defp split_attrs_and_directives(attrs) do
    Enum.split_with(attrs, fn {_name, %type{}} -> type == AST.Attribute end)
  end

  def handle_attribute(state, context, name, value, attr_meta) do
    meta = to_meta(state, attr_meta)

    {normalized_name, modifiers} = Surface.Directive.name_and_modifiers(name)

    directive = find_directive(context.type, context.module, normalized_name)

    if directive do
      {String.to_atom(normalized_name),
       %Surface.Directive{
         module: directive,
         original_name: name,
         modifiers: modifiers,
         name: normalized_name,
         value: parse_value(state, directive.type(), name, value, meta),
         meta: meta
       }}
    else
      {type, type_opts} = attribute_type_and_opts(context, name, meta)

      {String.to_atom(name),
       %Surface.AST.Attribute{
         type: type,
         type_opts: type_opts,
         name: name,
         value: parse_value(state, type, name, value, meta),
         meta: meta
       }}
    end
  end

  defp find_directive(type, module, normalized_name)
  defp find_directive(_type, _module, nil), do: nil

  defp find_directive(type, module, normalized_name) do
    Enum.find(@directives, fn directive ->
      directive.matches?(type, module, normalized_name)
    end)
  end

  def context_for_node(state, name, meta) do
    {node_type, node_alias} = node_type_and_alias(name, meta)
    module = module_for_node(state, node_type, node_alias, meta)

    ast_meta = to_meta(state, meta, node_alias: node_alias, module: module)

    %{
      type: node_type,
      meta: ast_meta,
      module: module,
      name: name
    }
  end

  def context_for_subblock(state, "#" <> name, %{type: Surface.Construct} = parent, meta) do
    case parent.module.validate_subblock(name) do
      :ok ->
        %{
          type: Surface.Construct.SubBlock,
          meta: to_meta(state, meta, node_alias: name, module: parent.module),
          module: parent.module,
          name: name
        }

      {:error, message} ->
        raise_unexpected_subblock_error!(name, parent, message, meta)
    end
  end

  def context_for_subblock(%{tags: []}, name, _, node_meta) do
    raise Parser.parse_error("<#{name}> is not allowed at the root of the template", node_meta)
  end

  def context_for_subblock(state, name, parent, node_meta) do
    raise_subblock_parent_not_a_construct_error!(state, name, parent, node_meta)
  end

  defp node_type_and_alias(<<"#", first, _rest::binary>> = name, _meta) when first in ?A..?Z,
    do: {AST.MacroComponent, String.slice(name, 1..-1)}

  defp node_type_and_alias(<<"#", first, _rest::binary>> = name, _meta) when first in ?a..?z,
    do: {Surface.Construct, String.slice(name, 1..-1)}

  defp node_type_and_alias(name, _meta) when name in ["template", "slot"],
    do: {Surface.Construct, name}

  defp node_type_and_alias(<<first, _::binary>> = name, _meta) when first in ?A..?Z,
    do: {AST.Component, name}

  defp node_type_and_alias(name, %{void_tag?: true}), do: {AST.VoidTag, name}
  defp node_type_and_alias(name, _meta), do: {AST.Tag, name}

  defp module_for_node(_state, Surface.Construct, name, meta) do
    if module = @constructs[name] do
      module
    else
      raise_unknown_construct_error!(name, meta)
    end
  end

  defp module_for_node(state, type, name, _meta)
       when type in [AST.Component, AST.MacroComponent] do
    Helpers.actual_component_module!(name, state.caller)
  end

  defp module_for_node(_state, _type, _name, _meta) do
    nil
  end

  defp attribute_type_and_opts(context, name, meta)
       when is_component(context) or is_tag(context) do
    Surface.TypeHandler.attribute_type_and_opts(context.module, name, meta)
  end

  defp attribute_type_and_opts(context, name, meta)
       when is_construct(context) or is_subblock(context) do
    block_name = if is_subblock(context), do: context.name, else: :default
    type = context.module.attribute_type(block_name, name, meta)
    {type, []}
  end

  defp parse_value(state, type, name, {:expr, value, expr_meta}, _attr_meta) do
    meta = to_meta(state, expr_meta)

    %AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(value, name, type, meta),
      meta: meta
    }
  end

  defp parse_value(_state, type, name, value, meta) do
    Surface.TypeHandler.literal_to_ast_node!(type, name, value, meta)
  end

  defp to_meta(state, parse_meta, extra \\ []) do
    %AST.Meta{
      line: parse_meta.line,
      column: parse_meta.column,
      file: parse_meta.file,
      caller: state.caller,
      checks: state.checks,
      node_alias: extra[:node_alias],
      module: extra[:module]
    }
  end

  defp raise_unexpected_subblock_error!(:default, parent, message, meta) do
    raise Parser.parse_error(
            """
            #{parent.name} requires all content to be wrapped in a subblock

            Hint: #{message}
            """,
            meta
          )
  end

  defp raise_unexpected_subblock_error!(name, parent, message, meta) do
    raise Parser.parse_error(
            """
            <#{name}> is not allowed inside #{parent.name}

            Hint: #{message}
            """,
            meta
          )
  end

  defp raise_unknown_construct_error!(name, meta) do
    message = "#{name} is not a known construct. Did you mean <#{name}> instead of <##{name}>?"
    raise Parser.parse_error(message, meta)
  end

  defp raise_subblock_parent_not_a_construct_error!(
         state,
         name,
         %{name: parent_name, meta: parent_meta},
         node_meta
       ) do
    {construct, tags_to_close} =
      Enum.reduce(state.tags, {nil, []}, fn
        {_, %{type: Surface.Construct} = ctx}, {nil, acc} ->
          {ctx, Enum.reverse(acc)}

        {_, ctx}, {nil, acc} ->
          {nil, [ctx.name | acc]}

        _, result ->
          result
      end)

    hint =
      if construct do
        """
        Did you mean to close #{Enum.join(", ", tags_to_close)} above line #{node_meta.line}? \
        That would associate this sub block with the <#{construct.name}> defined on line #{
          construct.line
        }.
        """
      else
        "None of the parent nodes are constructs. You may have closed a previous construct too early \
        or forgotten to include one."
      end

    message = """
    <#{parent_name}> on line #{parent_meta.line} is not a construct, and so does not \
    support the <#{name}> sub block.

    Hint: #{hint}
    """

    raise Parser.parse_error(message, node_meta)
  end
end
