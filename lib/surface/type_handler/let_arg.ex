defmodule Surface.TypeHandler.LetArg do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_quoted(type, name, clauses, opts, meta, original)

  def expr_to_quoted(_type, _name, [clause], [], _meta, _original) do
    {:ok, clause}
  end

  def expr_to_quoted(_type, _name, [], opts, _meta, original) do
    if original |> String.trim() |> String.starts_with?("[") do
      {:ok, opts}
    else
      {:ok, {:%{}, [], opts}}
    end
  end

  def expr_to_quoted(_type, "arg", _clauses, _opts, _meta, _original) do
    {:error, "Expected a single expression to be given as the slot argument"}
  end

  def expr_to_quoted(_type, ":let", _clauses, _opts, _meta, _original) do
    {:error, "Expected a pattern to be matched by the slot argument"}
  end
end
