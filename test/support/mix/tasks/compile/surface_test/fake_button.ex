defmodule Mix.Tasks.Compile.SurfaceTest.FakeButton do
  use Surface.Component

  def render(assigns) do
    ~F"""
    FAKE BUTTON
    """
  end
end
