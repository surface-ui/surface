defmodule Surface.Translator do
  alias Surface.Translator.{TagNode, ComponentNode, Parser}

  def run(string, line_offset, caller) do
    string
    |> Parser.parse(line_offset)
    |> put_module_info(caller)
    |> prepend_context()
    |> translate(caller)
    |> IO.iodata_to_binary()
  end

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> run(line_offset, __CALLER__)
    |> EEx.compile_string(engine: Phoenix.LiveView.Engine, line: line_offset)
  end

  def translate(nodes, caller) when is_list(nodes) do
    for node <- nodes do
      translate(node, caller)
    end
  end

  def translate({<<first, _::binary>>, _, _, _} = node, caller) when first in ?A..?Z do
    ComponentNode.translate(node, caller)
  end

  def translate({tag, _, _, _} = node, caller) when is_binary(tag) do
    TagNode.translate(node, caller)
  end

  def translate(node, _caller) do
    node
  end

  defp prepend_context(parsed_code) do
    ["<% context = %{} %><% _ = context %>" | parsed_code]
  end

  defp put_module_info([], _caller) do
    []
  end

  defp put_module_info([{<<first, _::binary>>, _, _, _} = node | nodes], caller)
      when first in ?A..?Z or first == ?# do
    {name, attributes, children, meta} = node

    name =
      case name do
        "#" <> name -> name
        _ -> name
      end

    children = put_module_info(children, caller)

    {:module, mod} =
      name
      |> actual_module(caller)
      |> Code.ensure_compiled()

    updated_node = {name, attributes, children, Map.put(meta, :module, mod)}
    [updated_node | put_module_info(nodes, caller)]
  end

  defp put_module_info([{tag_name, _, _, _} = node | nodes], caller) when is_binary(tag_name) do
    {_, attributes, children, meta} = node

    children = put_module_info(children, caller)
    updated_node = {tag_name, attributes, children, meta}
    [updated_node | put_module_info(nodes, caller)]
  end

  defp put_module_info([node | nodes], caller) do
    [node | put_module_info(nodes, caller)]
  end

  defp put_module_info(nodes, _caller) do
    nodes
  end

  defp actual_module(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)
    Macro.expand(ast, env)
  end
end
