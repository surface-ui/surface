defmodule Surface.Components.Form.TelephoneInput do
  @moduledoc """
  An input field that let the user enter a **telephone number**.

  Provides a wrapper for Phoenix.HTML.Form's `telephone_input/3` function.

  All options passed via `opts` will be sent to `telephone_input/3`, `value`,
  `pattern` and `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TelephoneInput form="user" field="phone" opts={{ autofocus: "autofocus" }} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [telephone_input: 3]
  import Surface.Components.Form.Utils

  @doc "A regular expression to validate the entered value"
  prop pattern, :string

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, :pattern, class: get_default_class()])
    event_opts = events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ telephone_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
