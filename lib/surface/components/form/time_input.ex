defmodule Surface.Components.Form.TimeInput do
  @moduledoc """
  Generates a time input.

  Provides a wrapper for Phoenix.HTML.Form's `time_input/3` function.

  All options passed via `opts` will be sent to `time_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TimeInput form="user" field="name" opts={{ [autofocus: "autofocus"] }}>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [time_input: 3]
  import Surface.Components.Form.Utils

  alias Surface.Components.Form, warn: false

  @doc "An identifier for the form"
  property form, :form

  @doc "An identifier for the input"
  property field, :string, required: true

  @doc "Value to pre-populated the input"
  property value, :string

  @doc "Class or classes to apply to the input"
  property class, :css_class

  @doc "Keyword list with options to be passed down to `time_input/3`"
  property opts, :keyword, default: []

  context get form, from: Form, as: :form_context

  def render(assigns) do
    form = get_form(assigns)
    props = get_non_nil_props(assigns, [:value, :class])

    ~H"""
    {{
      time_input(
        form,
        String.to_atom(@field),
        props ++ @opts
      )
    }}
    """
  end
end
