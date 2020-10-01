defmodule Surface.Components.Form.ColorInput do
  @moduledoc """
  An input field that let the user specify a **color**, either with a
  text field or a color picker interface.

  Provides a wrapper for Phoenix.HTML.Form's `color_input/3` function.

  All options passed via `opts` will be sent to `color_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <ColorInput form="user" field="color" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [color_input: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    props = get_non_nil_props(assigns, [:value, class: get_config(:default_class)])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ color_input(form, field, props ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
