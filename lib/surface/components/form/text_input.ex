defmodule Surface.Components.Form.TextInput do
  @moduledoc """
  Generates a text input.

  Provides a wrapper for Phoenix.HTML.Form's `text_input/3` function.

  All options passed via `opts` will be sent to `text_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TextInput form="user" field="name" opts={{ [autofocus: "autofocus"] }}>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form

  @doc "An identifier for the input"
  property field, :string, required: true

  @doc "Value to pre-populated the input"
  property value, :string

  @doc "Class or classes to apply to the input"
  property class, :css_class

  @doc "Keyword with options to be passed down to `text_input/3`"
  property opts, :keyword, default: []

  def render(assigns) do
    ~H"""
    {{
      text_input(
        String.to_atom(@form),
        @field,
        [
          value: @value,
          class: @class,
        ] ++ @opts
      )
    }}
    """
  end
end
