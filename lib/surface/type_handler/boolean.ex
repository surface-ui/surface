defmodule Surface.TypeHandler.Boolean do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_name, _type, "", _meta) do
    {:ok, %Surface.AST.Literal{value: true}}
  end

  def literal_to_ast_node(name, type, value, meta) do
    super(name, type, value, meta)
  end

  @impl true
  def expr_to_value([value], []) do
    {:ok, !!value}
  end
end
