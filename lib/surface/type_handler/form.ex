defmodule Surface.TypeHandler.Form do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_name, _type, value, _meta) when is_binary(value) do
    {:ok, %Surface.AST.Literal{value: String.to_atom(value)}}
  end

  def literal_to_ast_node(_name, _type, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_value([%Phoenix.HTML.Form{} = value], [], _ctx) do
    {:ok, value}
  end

  @impl true
  def expr_to_value([value], [], _ctx) when is_atom(value) do
    {:ok, value}
  end

  def expr_to_value(clauses, opts, _ctx) do
    {:error, clauses ++ opts}
  end
end
