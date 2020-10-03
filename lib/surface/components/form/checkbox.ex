defmodule Surface.Components.Form.Checkbox do
  @moduledoc """
  Defines a checkbox.

  Provides a wrapper for Phoenix.HTML.Form's `checkbox/3` function.

  All options passed via `opts` will be sent to `checkbox/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <RadioButton form="user" field="color" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [checkbox: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, [:checked, class: get_config(:default_class)])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{ checkbox(form, field, props ++ @opts ++ event_opts) }}
    """
  end
end
