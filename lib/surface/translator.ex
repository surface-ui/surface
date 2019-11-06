defmodule Surface.Translator do
  alias Surface.Translator.{TagNode, ComponentNode, Parser, NodeTranslator}

  def run(string, line_offset, caller) do
    string
    |> Parser.parse(line_offset)
    |> put_module_info(caller)
    |> prepend_context()
    |> NodeTranslator.translate(caller)
    |> IO.iodata_to_binary()
  end

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> run(line_offset, __CALLER__)
    |> EEx.compile_string(engine: Phoenix.LiveView.Engine, line: line_offset)
  end

  defp prepend_context(parsed_code) do
    ["<% context = %{} %><% _ = context %>" | parsed_code]
  end

  defp put_module_info([], _caller) do
    []
  end

  defp put_module_info([%ComponentNode{name: name} = node | nodes], caller) do
    mod = actual_module(name, caller)
    mod = if Code.ensure_compiled?(mod), do: mod, else: nil

    updated_node = %ComponentNode{node |
      module: mod,
      children: put_module_info(node.children, caller)
    }
    [updated_node | put_module_info(nodes, caller)]
  end

  defp put_module_info([%TagNode{children: children} = node | nodes], caller) do
    updated_node = %TagNode{node |
      children: put_module_info(children, caller)
    }
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
