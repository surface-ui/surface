defmodule Mix.Tasks.Compile.SurfaceTest.FakeButton do
  use Surface.Component

  def render(assigns) do
    ~H"""
    FAKE BUTTON
    """
  end
end
