defmodule Surface.Components.Form.RadioButton do
  @moduledoc """
  Generates a color input.

  Provides a wrapper for Phoenix.HTML.Form's `radio_button/4` function.

  All options passed via `opts` will be sent to `radio_button/4`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <RadioButton form="user" field="color" opts={{ [autofocus: "autofocus"] }}>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [radio_button: 4]
  import Surface.Components.Form.Utils

  alias Surface.Components.Form

  @doc "An identifier for the form"
  property form, :form

  @doc "An identifier for the input"
  property field, :string, required: true

  @doc "Value to pre-populated the input"
  property value, :string, required: true

  @doc "Class or classes to apply to the input"
  property class, :css_class

  @doc "Keyword list with options to be passed down to `radio_button/4`"
  property opts, :keyword, default: []

  @doc "Triggered when the component loses focus"
  property blur, :event

  @doc "Triggered when the component receives focus"
  property focus, :event

  @doc "Triggered when the component receives click"
  property capture_click, :event

  @doc "Triggered when a button on the keyboard is pressed"
  property keydown, :event

  @doc "Triggered when a button on the keyboard is released"
  property keyup, :event

  context get form, from: Form, as: :form_context

  def render(assigns) do
    form = get_form(assigns)
    props = get_non_nil_props(assigns, [:class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{
      radio_button(
        form,
        String.to_atom(@field),
        assigns[:value],
        props ++ @opts ++ event_opts
      )
    }}
    """
  end
end
