defmodule Surface.Components.Form.RangeInput do
  @moduledoc """
  Generates a text input.

  Provides a wrapper for Phoenix.HTML.Form's `range_input/3` function.

  All options passed via `opts` will be sent to `range_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <RangeInput form="volume" field="percent" min: "0" max: "100"/>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [range_input: 3]
  import Surface.Components.Form.Utils

  alias Surface.Components.Form, warn: false

  @doc "An identifier for the form"
  property form, :form

  @doc "An identifier for the input"
  property field, :string, required: true

  @doc "Value to pre-populated the input"
  property value, :string

  @doc "Minimum value for the input"
  property min, :string

  @doc "Maximum value for the input"
  property max, :string

  @doc "Class or classes to apply to the input"
  property class, :css_class

  @doc "Keyword list with options to be passed down to `range_input/3`"
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
    props = get_non_nil_props(assigns, [:value, :min, :max, :class])

    ~H"""
    {{
      range_input(
        form,
        String.to_atom(@field),
        props ++ @opts
      )
    }}
    """
  end
end
