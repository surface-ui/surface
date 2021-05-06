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
  alias Surface.Compiler.Parser

  defguardp is_component(context) when context.type in [AST.Component, AST.MacroComponent]
  defguardp is_construct(context) when context.type == Surface.Construct
  defguardp is_subblock(context) when context.type == Surface.Construct.SubBlock
  defguardp is_tag(context) when context.type in [AST.Tag, AST.VoidTag]

  def handle_comment(state, _comment), do: {state, :ignore}

  def handle_literal(state, value) do
    {state, %AST.Literal{value: value}}
  end

  def handle_end(_state, children) do
    children
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

  def handle_attribute(state, context, name, value, attr_meta) do
    meta = to_meta(state, attr_meta)

    normalized_name = Surface.Directive.normalize_name(name)

    directive =
      Enum.find(@directives, fn directive ->
        directive.matches?(context.type, normalized_name)
      end)

    if directive do
      %Surface.Directive{
        module: directive,
        original_name: name,
        name: normalized_name,
        value: parse_value(state, directive.type(), name, value, meta),
        meta: meta
      }
    else
      {type, type_opts} = attribute_type_and_opts(context, name, meta)

      %Surface.AST.Attribute{
        type: type,
        type_opts: type_opts,
        name: name,
        value: parse_value(state, type, name, value, meta),
        meta: meta
      }
    end
  end

  def context_for_node(state, name, meta) do
    {node_type, node_alias} = node_type_and_alias(name, meta)
    module = module_for_node(state, node_type, node_alias, meta)

    ast_meta = to_meta(state, meta, node_alias: node_alias, module: module)

    %{
      type: node_type,
      meta: ast_meta,
      module: module,
      name: name,
      allowed_subblocks:
        if(node_type == Surface.Construct, do: module.valid_subblocks(), else: nil)
    }
  end

  def context_for_subblock(state, :default = name, %{type: Surface.Construct} = parent, meta) do
    if name in parent.allowed_subblocks do
      %{
        type: Surface.Construct.SubBlock,
        meta: to_meta(state, meta, node_alias: name, module: parent.module),
        module: parent.module,
        name: name
      }
    else
      raise_default_subblock_not_allowed_error!(parent, meta)
    end
  end

  def context_for_subblock(state, "#" <> name, %{type: Surface.Construct} = parent, meta) do
    if name in parent.allowed_subblocks do
      %{
        type: Surface.Construct.SubBlock,
        meta: to_meta(state, meta, node_alias: name, module: parent.module),
        module: parent.module,
        name: name
      }
    else
      raise_unexpected_subblock_error!(name, parent, meta)
    end
  end

  def context_for_subblock(%{tags: []}, name, _, node_meta) do
    raise Parser.parse_error("<#{name}> is not allowed at the root of the template", node_meta)
  end

  def context_for_subblock(state, name, parent, node_meta) do
    raise_subblock_parent_not_a_construct_error!(state, name, parent, node_meta)
  end

  defp node_type_and_alias(<<"#", first, rest::binary>>, _meta) when first in ?A..?Z,
    do: {AST.MacroComponent, rest}

  defp node_type_and_alias(<<"#", first, rest::binary>>, _meta) when first in ?a..?z,
    do: {Surface.Construct, rest}

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

  defp raise_default_subblock_not_allowed_error!(parent, meta) do
    message = """
    #{parent.name} requires all content to be wrapped in one of the following \
    sub blocks: #{Enum.join(parent.allowed_subblocks)}
    """

    raise Parser.parse_error(message, meta)
  end

  defp raise_unexpected_subblock_error!(name, parent, meta) do
    hint =
      if Enum.empty?(parent.allowed_subblocks) do
        "#{parent.name} does not support any sub blocks. Did you mean to use another construct?"
      else
        "#{parent.name} only supports the following subblock(s): #{
          Enum.join(parent.allowed_subblocks)
        }"
      end

    raise Parser.parse_error(
            """
            <#{name}> is not allowed inside #{parent.name}

            Hint: #{hint}
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
        will associate this sub block with the <#{construct.name}> defined on line #{
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
