defmodule Mix.Tasks.Compile.SurfaceTest.FakeButton do
  use Surface.Component

  data color, :string

  def render(assigns) do
    assigns = assign(assigns, :color, "red")

    ~F"""
    <button class="btn">
      FAKE BUTTON
    </button>
    """
  end
end
