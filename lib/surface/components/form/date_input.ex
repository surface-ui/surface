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
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, class: get_config(:default_class)])
    event_opts = events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ date_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
