defmodule Surface.Components.Form.PasswordInput do
  @moduledoc """
  Generates a password input.

  Provides a wrapper for Phoenix.HTML.Form's `password_input/3` function.

  All options passed via `opts` will be sent to `password_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <PasswordInput form="user" field="password" opts={{ [autofocus: "autofocus"] }}>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [password_input: 3]
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

  @doc "Keyword list with options to be passed down to `password_input/3`"
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
    props = get_non_nil_props(assigns, [:value, :class])

    ~H"""
    {{
      password_input(
        form,
        String.to_atom(@field),
        props ++ @opts
      )
    }}
    """
  end
end
