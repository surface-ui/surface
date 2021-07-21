defmodule Surface.Components.Form.UrlInput do
  @moduledoc """
  An input field that let the user enter a **URL**.

  Provides a wrapper for Phoenix.HTML.Form's `url_input/3` function.

  All options passed via `opts` will be sent to `url_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <UrlInput form="user" field="name" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [url_input: 3]
  import Surface.Components.Utils, only: [events_to_opts: 1]
  import Surface.Components.Form.Utils

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, class: get_default_class()])
    event_attrs = events_to_opts(assigns)

    ~F"""
    <InputContext assigns={assigns} :let={form: form, field: field}>
      {url_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_attrs)}
    </InputContext>
    """
  end
end
