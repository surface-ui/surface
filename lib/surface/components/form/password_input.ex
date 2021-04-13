defmodule Surface.Components.Form.PasswordInput do
  @moduledoc """
  An input field that let the user securely specify a **password**.

  Provides a wrapper for Phoenix.HTML.Form's `password_input/3` function.

  All options passed via `opts` will be sent to `password_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <PasswordInput form="user" field="password" opts={{ autofocus: "autofocus" }} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [password_input: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, class: get_config(:default_class)])
    event_opts = events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ password_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
