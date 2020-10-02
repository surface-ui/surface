defmodule Surface.TypeHandler.ContextSet do
  @moduledoc false

  use Surface.TypeHandler

  @error_message """
  expected a scope module (optional) along with a keyword list of values, \
  e.g. {{ MyModule, field: @value, other: "other" }} or {{ field: @value }}\
  """

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, [scope], [_ | _] = values, _meta, _original) do
    if is_scope?(scope) do
      {:ok, {scope, values}}
    else
      {:error, @error_message}
    end
  end

  @impl true
  def expr_to_quoted(_type, _name, [], values, _meta, _original) do
    {:ok, {nil, values}}
  end

  @impl true
  def expr_to_quoted(_type, _name, _clauses, _opts, _meta, _original) do
    {:error, @error_message}
  end

  defp is_scope?(scope) do
    match?({:__aliases__, _, _}, scope) or match?({:__MODULE__, [_ | _], nil}, scope)
  end
end
