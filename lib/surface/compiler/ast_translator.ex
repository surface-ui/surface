defmodule Surface.Compiler.AstTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.AST
  alias Surface.Compiler.Helpers
  alias Surface.Compiler.Parser

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
        name: "#" <> name
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
    # :-/
    construct_module_name = "Surface.Constructs.#{String.capitalize(name)}"
    module = Helpers.actual_component_module!(construct_module_name, __ENV__)

    if function_exported?(module, :valid_subblocks, 0) do
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
