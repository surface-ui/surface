defmodule Mix.Tasks.Compile.SurfaceTest.MultipleStyles do
  use Surface.Component

  def render(assigns) do
    ~F"""
    <style>
      .panel { padding: 10px; }
    </style>
    <div class="panel">
    FAKE PANEL
    </div>
    """
  end
end
