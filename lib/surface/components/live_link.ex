defmodule Surface.Components.LiveLink do
  use Surface.Component

  property label, :string
  property to, :string
  property class, :css_class

  def render(assigns) do
    Phoenix.LiveView.live_link(assigns.label, to: assigns.to, class: assigns.class)
  end
end
