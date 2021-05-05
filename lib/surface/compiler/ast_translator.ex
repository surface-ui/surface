defmodule Surface.Compiler.AstTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.IOHelper
  alias Surface.AST
  alias Surface.Compiler.Helpers

  def handle_comment(_state, _comment), do: :ignore

  def handle_text(_state, text) do
    %AST.Literal{value: text}
  end

  def handle_end(_state, children) do
    children
  end

  def handle_interpolation(state, expression, parse_meta) do
    ast_meta = to_meta(state, parse_meta)

    %AST.Interpolation{
      original: expression,
      value: Helpers.interpolation_to_quoted!(expression, ast_meta),
      meta: ast_meta
    }
  end

  def context_for_node(state, name, meta) do
    {node_type, node_alias} = node_type_and_alias(name, meta)
    module = module_for_node(state, node_type, node_alias)

    ast_meta = to_meta(state, meta, node_alias: node_alias, module: module)

    %{
      type: node_type,
      meta: ast_meta,
      module: module,
      name: name
    }
  end

  defp node_type_and_alias(<<"#", first, rest::binary>>, _meta) when first in ?A..?Z,
    do: {AST.MacroComponent, rest}

  defp node_type_and_alias(<<"#", first, rest::binary>>, _meta) when first in ?a..?z,
    do: {AST.Construct, rest}

  defp node_type_and_alias(<<first, _::binary>> = name, _meta) when first in ?A..?Z,
    do: {AST.Construct, name}

  defp node_type_and_alias(name, %{void_tag?: true}), do: {AST.VoidTag, name}
  defp node_type_and_alias(name, _meta), do: {AST.Tag, name}

  defp module_for_node(_state, AST.Construct, name) do
    # :-/
    construct_module_name = "Surface.Constructs.#{String.capitalize(name)}"
    Helpers.actual_component_module!(construct_module_name, __ENV__)
  end

  defp module_for_node(state, type, name) when type in [AST.Component, AST.MacroComponent] do
    Helpers.actual_component_module!(name, state.caller)
  end

  defp module_for_node(_state, _type, _name) do
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
end
