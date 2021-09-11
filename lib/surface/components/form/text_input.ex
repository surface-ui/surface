defmodule Surface.Components.Form.TextInput do
  @moduledoc """
  An input field that let the user enter a **single-line text**.

  Provides a wrapper for Phoenix.HTML.Form's `text_input/3` function.

  All options passed via `opts` will be sent to `text_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TextInput form="user" field="name" opts={autofocus: "autofocus"} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [text_input: 3]
  import Surface.Components.Utils, only: [events_to_opts: 1]
  import Surface.Components.Form.Utils

  @doc "An example value to display inside the field when it has no value"
  prop placeholder, :string

  def render(assigns) do
    helper_opts = props_to_opts(assigns, [])
    attr_opts = props_to_attr_opts(assigns, [:value, :placeholder, class: get_default_class()])
    event_opts = events_to_opts(assigns)

    opts =
      assigns.opts
      |> Keyword.merge(helper_opts)
      |> Keyword.merge(attr_opts)
      |> Keyword.merge(event_opts)

    assigns = assign(assigns, opts: opts)

    ~F"""
    <InputContext assigns={assigns} :let={form: form, field: field}>
      {text_input(form, field,  @opts)}
    </InputContext>
    """
  end
end
