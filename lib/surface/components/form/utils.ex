defmodule Surface.Components.Form.Utils do
  @moduledoc false
  import Surface, only: [event_to_opts: 2, prop_to_opts: 2]

  alias Surface.Components.Form
  alias Surface.Components.Form.Field
  alias Surface.Components.Context

  def get_form(assigns) do
    context_form = Context.get(assigns, :form, scope: Form)
    maybe_to_atom(assigns[:form] || context_form)
  end

  def get_field(assigns) do
    context_field = Context.get(assigns, :field, scope: Field)
    maybe_to_atom(assigns[:field] || context_field)
  end

  defmacro get_non_nil_props(assigns, props) do
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

  defp maybe_to_atom(form) do
    if is_binary(form) do
      String.to_atom(form)
    else
      form
    end
  end
end
