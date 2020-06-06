defmodule Surface.Components.Form.Utils do
  @moduledoc false
  import Surface, only: [event_to_opts: 2]

  def get_form(%{form: form}) when is_binary(form), do: String.to_atom(form)
  def get_form(%{form: nil, form_context: form_context}), do: form_context

  def get_field(%{field: field}) when is_binary(field), do: String.to_atom(field)
  def get_field(%{field: nil, field_context: field_context}), do: field_context

  def get_non_nil_props(assigns, props) do
    for prop <- props, not is_nil(assigns[prop]) do
      {prop, assigns[prop]}
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
end
