defmodule Surface.TypeHandler.ContextGet do
  @moduledoc false

  use Surface.TypeHandler

  @error_message """
  expected a scope module (optional) along with a keyword list of bindings, \
  e.g. {{ Form, form: form }} or {{ field: my_field }}\
  """

  @impl true
  def literal_to_ast_node(_type, _name, _value, _meta) do
    :error
  end

  @impl true
  def expr_to_quoted(_type, _name, [scope], bindings, _meta, _original) do
    is_binding? = fn {_key, var} -> match?({name, [_ | _], nil} when is_atom(name), var) end

    if is_scope?(scope) and Enum.all?(bindings, is_binding?) do
      {:ok, {scope, bindings}}
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
