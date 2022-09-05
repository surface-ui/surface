defmodule Surface.TypeHandler.Generator do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_quoted(_type, ":for", clauses, [], _meta, _original) do
    {:ok, clauses}
  end

  def expr_to_quoted(_type, :root, clauses, [], _meta, _original) do
    {:ok, clauses}
  end

  def expr_to_quoted(_type, _name, [{:<-, _, [binding, value]}], [], _meta, _original) do
    {:ok, {:__generator__, binding, value}}
  end

  def expr_to_quoted(_type, _attribute_name, _clauses, _opts, _meta, _original) do
    {:error, "Expected a :generator Example: `{i <- ...}`"}
  end
end
