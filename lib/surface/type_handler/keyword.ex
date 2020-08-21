defmodule Surface.TypeHandler.Keyword do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(type, name, value, meta) do
    %Surface.AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(Macro.to_string(value), name, type, meta),
      meta: meta
    }
  end

  @impl true
  def expr_to_value([value], []) do
    if is_list(value) and Keyword.keyword?(value) do
      {:ok, value}
    else
      {:error, value}
    end
  end

  def expr_to_value([], opts) do
    {:ok, opts}
  end

  def expr_to_value(clauses, opts) do
    {:error, clauses ++ opts}
  end
end
