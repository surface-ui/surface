defmodule Surface.Components.LiveRedirect do
  @moduledoc """
  A module providing similar capabilities to the live_redirect function
  """
  use Surface.Component

  property(to, :string, required: true)
  property(replace, :boolean, default: false)
  property(class, :css_class, default: "")

  def render(%{replace: replace} = assigns) do
    link_state = if replace, do: "replace", else: "push"

    ~H"""
    <a
      data-phx-link="redirect"
      data-phx-link-state={{ link_state }}
      class={{ @class }}
      href={{ @to }}
      to={{ @to }}
    >
      {{ @inner_content.() }}
    </a>
    """
  end
end
