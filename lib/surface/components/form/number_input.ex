defmodule Surface.Components.Form.NumberInput do
  @moduledoc """
  An input field that let the user to enter a **number**.

  Provides a wrapper for Phoenix.HTML.Form's `number_input/3` function.

  All options passed via `opts` will be sent to `number_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <NumberInput form="user" field="age" opts={autofocus: "autofocus"} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [number_input: 3]
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

    ~F"""
    <InputContext assigns={assigns} :let={form: form, field: field}>
      {number_input(form, field, @opts)}
    </InputContext>
    """
  end
end
