defmodule Surface.Components.Form.FileInput do
  @moduledoc """
  Generates a file input.

  It requires the given form to be configured with `multipart: true`.

  All options passed via `opts` will be sent to `file_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <Form for={:user} multipart={true}>
    <FileInput field={:picture} />
  </Form>
  ```
  """

  use Surface.Components.Form.Input

  import PhoenixHTMLHelpers.Form, only: [file_input: 3]
  import Surface.Components.Utils, only: [events_to_opts: 1]
  import Surface.Components.Form.Utils

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, class: get_default_class()])
    event_opts = events_to_opts(assigns)

    opts =
      assigns.opts
      |> Keyword.merge(helper_opts)
      |> Keyword.merge(attr_opts)
      |> Keyword.merge(event_opts)

    assigns = assign(assigns, opts: opts)

    ~F[{file_input(@form, @field, @opts)}]
  end
end
