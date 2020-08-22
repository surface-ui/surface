defmodule Surface.TypeHandler.Keyword do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
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
