defmodule Surface.TypeHandler.Bindings do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_quoted(_type, _name, clauses, opts, _meta, _original) do
    match_binding? = &match?({_prop, {var, _, nil}} when is_atom(var), &1)

    if clauses == [] and Enum.all?(opts, match_binding?) do
      {:ok, opts}
    else
      {:error, "Expected a keyword list of bindings"}
    end
  end
end
