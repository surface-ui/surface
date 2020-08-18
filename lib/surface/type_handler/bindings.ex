defmodule Surface.TypeHandler.Bindings do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def validate_expr(clauses, opts, _module) do
    match_binding? = &match?({_prop, {var, _, nil}} when is_atom(var), &1)

    if clauses == [] and Enum.all?(opts, match_binding?) do
      :ok
    else
      {:error, "Expected a keyword list of bindings"}
    end
  end

  @impl true
  def expr_to_quoted(_type, _attribute_name, _clauses, opts, _module, _original) do
    opts
  end
end
