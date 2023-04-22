defmodule Mix.Tasks.Compile.SurfaceTest.FakeLink do
  use Surface.Component

  def render(assigns) do
    ~F"""
    <style>
      @import "./fake_link.css";

      .link { padding: 10px; }
    </style>
    FAKE LINK
    """
  end
end
