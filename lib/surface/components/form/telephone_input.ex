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

  context get form, from: Form, as: :form_context
  context get field, from: Field, as: :field_context

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, [:value, :pattern, :class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{ telephone_input(form, field, props ++ @opts ++ event_opts) }}
    """
  end
end
