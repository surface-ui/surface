defmodule Mix.Tasks.Compile.SurfaceTest.FakeLink do
  use Surface.Component

  def render(assigns) do
    ~H"""
    FAKE LINK
    """
  end
end
