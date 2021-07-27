defmodule Surface.Components.Form.Reset do
  @moduledoc """
  Defines a reset button.

  Provides a wrapper for Phoenix.HTML.Form's `reset/2` function.

  All options passed via `opts` will be sent to `reset/2`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <Reset value="Reset" opts={autofocus: "autofocus"} />
  ```
  """

  use Surface.Component
  use Surface.Components.Events

  import Phoenix.HTML.Form, only: [reset: 2]
  import Surface.Components.Utils, only: [events_to_opts: 1]
  import Surface.Components.Form.Utils

  @doc "The id of the corresponding input field"
  prop id, :string

  @doc "The name of the corresponding input field"
  prop name, :string

  @doc "Value to pre-populated the input"
  prop value, :string, default: "Reset"

  @doc "Class or classes to apply to the input"
  prop class, :css_class

  @doc "Keyword list with options to be passed down to `reset/2`"
  prop opts, :keyword, default: []

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:class])
    event_opts = events_to_opts(assigns)

    opts =
      assigns.opts
      |> Keyword.merge(helper_opts)
      |> Keyword.merge(attr_opts)
      |> Keyword.merge(event_opts)

    assigns = assign(assigns, opts: opts)

    ~F"""
    {reset(assigns[:value], @opts)}
    """
  end
end
