defmodule Mix.Tasks.Compile.SurfaceTest.FakeLink do
  use Surface.Component

  def render(assigns) do
    ~F"""
    FAKE LINK
    """
  end
end
