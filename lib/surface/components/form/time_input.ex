defmodule Surface.Components.Form.TimeInput do
  @moduledoc """
  An input field that let the user enter a **time** (hours, minutes and
  optionally seconds).

  Provides a wrapper for Phoenix.HTML.Form's `time_input/3` function.

  All options passed via `opts` will be sent to `time_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TimeInput form="user" field="name" opts={autofocus: "autofocus"} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [time_input: 3]
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

    ~F[{time_input(@form, @field, @opts)}]
  end
end
