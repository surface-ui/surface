defmodule Surface.Components.Context do
  use Surface.Component

  property set, :context_set, default: %{}
  property get, :map, default: %{}

  slot default, required: true

  def render(assigns) do
    ~H"""
    {{ @__original_inner_content.(slot_kw() ++ context_assigns_kw(@__context2__, @set, @get)) }}
    """
  end

  defp slot_kw() do
    [__slot__: {:__default__, 0}]
  end

  defp context_assigns_kw(context, set, get) do
    updated_context = Map.merge(context, Map.new(set))
    context_kw(updated_context, set) ++ context_gets_kw(updated_context, get)
  end

  defp context_kw(context, set) do
    if set == %{} do
      []
    else
      [__context2__: context]
    end
  end

  defp context_gets_kw(context, get) do
    Enum.map(get, fn {k, v} -> {v, context[k]} end)
  end
end
