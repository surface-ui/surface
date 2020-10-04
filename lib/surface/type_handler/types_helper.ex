defmodule Surface.TypeHandler.TypesHelper do
  @moduledoc false

  def extract_scope(clauses) do
    case clauses do
      [scope] ->
        if is_scope?(scope) do
          {:ok, scope}
        else
          :error
        end

      [] ->
        {:ok, nil}

      _ ->
        :error
    end
  end

  def is_bindings?(bindings) do
    is_binding? = fn {_key, var} -> match?({name, [_ | _], nil} when is_atom(name), var) end
    bindings != [] and Enum.all?(bindings, is_binding?)
  end

  defp is_scope?(scope) do
    is_atom(scope) or
      match?({:__aliases__, _, _}, scope) or
      match?({:__MODULE__, [_ | _], nil}, scope)
  end
end
