defmodule Surface.Components.Form.Reset do
  @moduledoc """
  Generates a color input.

  Provides a wrapper for Phoenix.HTML.Form's `reset/2` function.

  All options passed via `opts` will be sent to `reset/2`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <Reset value="Reset" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [reset: 2]
  import Surface.Components.Form.Utils

  @doc "Value to pre-populated the input"
  property value, :string, default: "Reset"

  @doc "Class or classes to apply to the input"
  property class, :css_class

  @doc "Keyword list with options to be passed down to `reset/2`"
  property opts, :keyword, default: []

  @doc "Triggered when the component loses focus"
  property blur, :event

  @doc "Triggered when the component receives focus"
  property focus, :event

  @doc "Triggered when the component receives click"
  property capture_click, :event

  @doc "Triggered when a button on the keyboard is pressed"
  property keydown, :event

  @doc "Triggered when a button on the keyboard is released"
  property keyup, :event

  def render(assigns) do
    props = get_non_nil_props(assigns, [:class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{
      reset(
        assigns[:value],
        props ++ @opts ++ event_opts
      )
    }}
    """
  end
end
