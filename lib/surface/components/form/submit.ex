defmodule Surface.Components.Form.Submit do
  @moduledoc """
  Defines a submit button to send the form.

  All options are forwarded to the underlying `Phoenix.HTML.Form.submit/3`
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [submit: 2]
  import Surface.Components.Form.Utils

  @doc "The label to be used in the button"
  prop label, :string

  @doc "Class or classes to apply to the button"
  prop class, :css_class

  @doc "Keyword list with options to be passed down to `submit/3`"
  prop opts, :keyword, default: []

  @doc "Triggered when the component loses focus"
  prop blur, :event

  @doc "Triggered when the component receives focus"
  prop focus, :event

  @doc "Triggered when the component receives click"
  prop capture_click, :event

  @doc "Triggered when a button on the keyboard is pressed"
  prop keydown, :event

  @doc "Triggered when a button on the keyboard is released"
  prop keyup, :event

  @doc "Slot used for having children other than plain text in the button"
  slot default

  def render(assigns) do
    children = ~H"<slot>{{ @label }}</slot>"
    event_opts = events_to_opts(assigns)

    ~H"""
    {{ submit prop_to_attr_opts(@class, :class) ++ @opts ++ event_opts, do: children }}
    """
  end
end
