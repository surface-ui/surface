defmodule Surface.Components.Form.Utils do
  @moduledoc false
  import Surface, only: [event_to_opts: 2, prop_to_opts: 2]

  defmacro get_non_nil_props(assigns, props) do
    # `id` and `name` props are common in all the form components
    props = [:id, :name] ++ props

    quote do
      Enum.reduce(unquote(props), [], fn prop, acc ->
        {key, value} = unquote(__MODULE__).prop_value(unquote(assigns), prop)
        prop_to_opts(value, key) ++ acc
      end)
    end
  end

  def get_events_to_opts(assigns) do
    [
      event_to_opts(assigns.blur, :phx_blur),
      event_to_opts(assigns.focus, :phx_focus),
      event_to_opts(assigns.capture_click, :phx_capture_click),
      event_to_opts(assigns.keydown, :phx_keydown),
      event_to_opts(assigns.keyup, :phx_keyup)
    ]
    |> List.flatten()
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
