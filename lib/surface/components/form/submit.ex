defmodule Surface.Components.Form.Submit do
  @moduledoc """
  Defines a submit button to send the form.

  All options are forwarded to the underlying `Phoenix.HTML.Form.submit/3`
  """

  use Surface.Component
  use Surface.Components.Events

  import Surface.Components.Utils, only: [events_to_opts: 1, opts_to_attrs: 1]

  @doc "The label to be used in the button"
  prop label, :string

  @doc "Class or classes to apply to the button"
  prop class, :css_class

  @doc "Keyword list with options to be passed down to `submit/3`"
  prop opts, :keyword, default: []

  @doc "Slot used for having children other than plain text in the button"
  slot default

  def render(assigns) do
    opts = prop_to_attr_opts(assigns.class, :class) ++ assigns.opts ++ events_to_opts(assigns)
    attrs = opts_to_attrs(opts)

    ~H"""
    <button type="submit" :attrs={{ attrs }}>
      <slot>{{ @label }}</slot>
    </button>
    """
  end
end
