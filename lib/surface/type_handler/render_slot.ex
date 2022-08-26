defmodule Surface.TypeHandler.RenderSlot do
  @moduledoc false

  use Surface.TypeHandler

  @impl true
  def expr_to_quoted(type, name, clauses, opts, meta, original)

  def expr_to_quoted(_type, _name, [slot], [], _meta, _original) do
    {:ok, %{slot: slot, argument: nil}}
  end

  def expr_to_quoted(_type, _name, [slot | [argument]], [], _meta, _original) do
    {:ok, %{slot: slot, argument: argument}}
  end

  def expr_to_quoted(_type, _name, [slot], opts, _meta, original) do
    literal_keyword? = original |> String.trim() |> String.ends_with?("]")

    argument =
      if literal_keyword? do
        opts
      else
        {:%{}, [], opts}
      end

    {:ok, %{slot: slot, argument: argument}}
  end

  def expr_to_quoted(_type, _name, _clauses, _opts, _meta, _original) do
    {:error, "Expected the slot and a single expression to be given as the slot argument"}
  end
end
