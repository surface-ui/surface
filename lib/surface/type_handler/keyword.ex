defmodule Surface.TypeHandler.Keyword do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_value([value], [], _ctx) do
    cond do
      is_list(value) and Keyword.keyword?(value) -> {:ok, value}
      is_map(value) and not is_struct(value) -> {:ok, Keyword.new(value)}
      true -> {:error, value}
    end
  end

  def expr_to_value([], opts, _ctx) do
    {:ok, opts}
  end

  def expr_to_value(clauses, opts, _ctx) do
    {:error, clauses ++ opts}
  end
end
