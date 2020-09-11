defmodule Surface.TypeHandler.ContextSet do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_value([key, value], opts) when is_atom(key) do
    # TODO: Validate opts at compile-time
    {:ok, {key, value, opts}}
  end

  def expr_to_value(clauses, opts) do
    {:error, clauses ++ opts}
  end
end
