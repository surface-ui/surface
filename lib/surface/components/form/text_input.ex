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

  import Phoenix.HTML.Form, only: [text_input: 3]

  alias Surface.Components.Form, warn: false

  @doc "An identifier for the form"
  property form, :string

  @doc "An identifier for the input"
  property field, :string, required: true

  @doc "Value to pre-populated the input"
  property value, :string

  @doc "Class or classes to apply to the input"
  property class, :css_class

  @doc "Keyword list with options to be passed down to `text_input/3`"
  property opts, :keyword, default: []

  context get form, from: Form, as: :form_context

  def render(assigns) do
    form = get_form(assigns)
    props = get_non_nil_props(assigns, [:value, :class])

    ~H"""
    {{
      text_input(
        form,
        String.to_atom(@field),
        props ++ @opts
      )
    }}
    """
  end

  defp get_form(%{form: form}) when is_binary(form) do
    String.to_atom(form)
  end

  defp get_form(%{form: nil, form_context: form_context}) do
    form_context
  end

  defp get_non_nil_props(assigns, props) do
    Enum.reduce(props, [], fn prop, acc ->
      if assigns[prop] do
        [{prop, assigns[prop]} | acc]
      else
        acc
      end
    end)
  end
end
