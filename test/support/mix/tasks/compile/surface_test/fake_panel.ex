defmodule Mix.Tasks.Compile.SurfaceTest.FakePanel do
  use Surface.Component

  def render(assigns) do
    ~F"""
    <style>
      .panel { padding: 10px; }
    </style>
    FAKE PANEL
    """
  end
end
