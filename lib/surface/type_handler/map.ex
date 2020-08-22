defmodule Surface.TypeHandler.Map do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_value([value], []) do
    cond do
      is_map(value) ->
        {:ok, value}

      is_list(value) and Keyword.keyword?(value) ->
        {:ok, Map.new(value)}

      true ->
        {:error, value}
    end
  end

  def expr_to_value([], opts) do
    {:ok, Map.new(opts)}
  end

  def expr_to_value(clauses, opts) do
    {:error, clauses ++ opts}
  end
end
