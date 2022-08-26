defmodule Surface.TypeHandler.Dynamic do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, value, _meta) do
    {:ok, %Surface.AST.Literal{value: value}}
  end

  @impl true
  def expr_to_quoted(_type, _name, clauses, opts, _meta, original) do
    quoted_expr =
      quote do
        {unquote(clauses), unquote(opts), unquote(original)}
      end

    {:ok, quoted_expr}
  end
end
