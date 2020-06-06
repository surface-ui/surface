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

  context get form, from: Form, as: :form_context
  context get field, from: Field, as: :field_context

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, [:value, :class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{ email_input(form, field, props ++ @opts ++ event_opts) }}
    """
  end
end
