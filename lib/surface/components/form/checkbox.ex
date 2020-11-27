defmodule Surface.Components.Form.Checkbox do
  @moduledoc """
  Defines a checkbox.

  Provides a wrapper for Phoenix.HTML.Form's `checkbox/3` function.

  All options passed via `opts` will be sent to `checkbox/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <Checkbox form="user" field="color" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [checkbox: 3]
  import Surface.Components.Form.Utils

  @doc "The value to be sent when the checkbox is checked. Defaults to \"true\""
  prop checked_value, :any, default: true

  @doc "Controls if this function will generate a hidden input to submit the unchecked value or not, defaults to \"true\"."
  prop hidden_input, :boolean, default: true

  @doc "The value to be sent when the checkbox is unchecked, defaults to \"false\"."
  prop unchecked_value, :any, default: false

  def render(assigns) do
    props =
      get_non_nil_props(assigns, [
        :checked_value,
        :hidden_input,
        :unchecked_value,
        :checked,
        class: get_config(:default_class)
      ])

    event_opts = get_events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
    {{ checkbox(form, field, props ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
