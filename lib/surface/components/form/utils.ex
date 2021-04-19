defmodule Surface.Components.Form.Utils do
  @moduledoc false
  import Surface, only: [prop_to_attr_opts: 2]

  def props_to_opts(assigns, props \\ []) do
    # `id` and `name` props are common in all the form components
    props = [:id, :name] ++ props

    for prop <- props,
        {key, value} = prop_value(assigns, prop),
        value != nil do
      {key, value}
    end
  end

  defmacro props_to_attr_opts(assigns, props) do
    quote do
      Enum.reduce(unquote(props), [], fn prop, acc ->
        {key, value} = unquote(__MODULE__).prop_value(unquote(assigns), prop)
        prop_to_attr_opts(value, key) ++ acc
      end)
    end
  end

  def prop_value(assigns, {prop, default}) when is_list(default) do
    {prop, assigns[prop] || default}
  end

  def prop_value(assigns, {prop, default}) do
    {prop, assigns[prop] || [default]}
  end

  def prop_value(assigns, prop) do
    {prop, assigns[prop]}
  end

  @doc false
  def parse_css_class_for(props, field) do
    parse_css_class_for(props, field, props[field][:class])
  end

  defp parse_css_class_for(props, field, class) when is_list(class) do
    put_in(props, [field, :class], Surface.css_class(class))
  end

  defp parse_css_class_for(props, _field, _class), do: props
end
