defmodule Surface.Components.Context do
  use Surface.Component

  property set, :context_set, accumulate: true, default: []
  property get, :context_get, accumulate: true, default: []

  slot default, required: true

  def render(assigns) do
    ~H"""
    {{ @__original_inner_content.(slot_kw() ++ context_assigns_kw(@__context2__, @set, @get)) }}
    """
  end

  @doc """
  Retrieve a value from the context.

  The `opts` argument can contain any option accepted by the `get` property,
  except `:as`, which is ignored.
  """
  def get(assigns, key, opts) do
    {key, _as} = normalize_get({key, opts})
    assigns.__context2__[key]
  end

  defp slot_kw() do
    [__slot__: {:__default__, 0}]
  end

  defp context_assigns_kw(context, sets, gets) do
    consolidated_sets =
      Enum.reduce(sets, %{}, fn set, acc ->
        {key, value} = normalize_set(set)
        Map.put(acc, key, value)
      end)

    updated_context = Map.merge(context, consolidated_sets)
    context_kw(updated_context, consolidated_sets) ++ context_gets_kw(updated_context, gets)
  end

  defp context_kw(context, set) do
    if set == %{} do
      []
    else
      [__context2__: context]
    end
  end

  defp context_gets_kw(context, gets) do
    Enum.map(gets, fn get ->
      {key, name} = normalize_get(get)
      {name, context[key]}
    end)
  end

  defp normalize_set({key, value, opts}) do
    case Keyword.get(opts, :scope) do
      nil ->
        {key, value}

      scope ->
        {{scope, key}, value}
    end
  end

  defp normalize_get({key, opts}) do
    full_key =
      case Keyword.get(opts, :scope) do
        nil ->
          key

        scope ->
          {scope, key}
      end

    {full_key, Keyword.get(opts, :as, key)}
  end
end
