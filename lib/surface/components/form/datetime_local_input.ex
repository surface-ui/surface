defmodule Surface.Components.Form.DateTimeLocalInput do
  @moduledoc """
  An input field that let the user enter both **date** and **time**, using a
  text field and a date picker interface.

  Provides a wrapper for Phoenix.HTML.Form's `datetime_local_input/3` function.

  All options passed via `opts` will be sent to `datetime_local_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <DateTimeLocalInput form="order" field="completed_at" opts={{ autofocus: "autofocus" }} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [datetime_local_input: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, class: get_config(:default_class)])
    event_opts = events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ datetime_local_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
