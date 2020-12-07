defmodule Surface.Components.Form.EmailInput do
  @moduledoc """
  An input field that let the user enter one or multiple **e-mails**.

  Provides a wrapper for Phoenix.HTML.Form's `email_input/3` function.

  All options passed via `opts` will be sent to `email_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <EmailInput form="user" field="email" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [email_input: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    props = get_non_nil_props(assigns, [:value, class: get_default_class()])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ email_input(form, field, props ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
