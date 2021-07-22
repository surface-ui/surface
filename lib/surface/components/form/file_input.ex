defmodule Surface.Components.Form.FileInput do
  @moduledoc """
  Generates a file input.

  It requires the given form to be configured with `multipart: true`.

  All options passed via `opts` will be sent to `file_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <FileInput form="user" field="picture" />

  <Form for={:user} opts={multipart: true}>
    <FileInput field={:picture} />
  </Form>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [file_input: 3]
  import Surface.Components.Utils, only: [events_to_attrs: 1]
  import Surface.Components.Form.Utils

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, class: get_default_class()])
    event_attrs = events_to_attrs(assigns)

    ~F"""
    <InputContext assigns={assigns} :let={form: form, field: field}>
      {file_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_attrs)}
    </InputContext>
    """
  end
end
