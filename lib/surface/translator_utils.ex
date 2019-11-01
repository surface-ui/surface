defmodule Surface.TranslatorUtils do
  alias Surface.Translator.{TagNode, ComponentNode}

  def put_module_info([], _caller) do
    []
  end

  def put_module_info([%ComponentNode{name: name} = node | nodes], caller) do
    mod = actual_module(name, caller)
    mod = if Code.ensure_compiled?(mod), do: mod, else: nil

    updated_node = %ComponentNode{node |
      module: mod,
      children: put_module_info(node.children, caller)
    }
    [ updated_node | put_module_info(nodes, caller)]
  end

  def put_module_info([%TagNode{children: children} = node | nodes], caller) do
    updated_node = %TagNode{node |
      children: put_module_info(children, caller)
    }
    [ updated_node | put_module_info(nodes, caller)]
  end

  def put_module_info([node | nodes], caller) do
    [ node | put_module_info(nodes, caller)]
  end

  def put_module_info(nodes, _caller) do
    nodes
  end

  defp actual_module(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)
    Macro.expand(ast, env)
  end
end
