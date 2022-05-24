defmodule SurfaceWeb.Components.FakeComponentInWebNamespace do
  use Surface.Component

  def render(assigns) do
    ~F"""
    Fake render
    """
  end
end
