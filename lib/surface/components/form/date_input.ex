defmodule Surface.Components.Form.DateInput do
  @moduledoc """
  An input field that let the user enter a **date**, either with a text field
  or a date picker interface.

  Provides a wrapper for Phoenix.HTML.Form's `date_input/3` function.

  All options passed via `opts` will be sent to `date_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <DateInput form="user" field="birthday" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [date_input: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, [:value, class: @default_class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{ date_input( form, field, props ++ @opts ++ event_opts) }}
    """
  end
end
