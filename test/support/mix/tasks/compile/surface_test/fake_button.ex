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

  def func(assigns) do
    assigns = assign(assigns, :padding, "10px;")

    ~F"""
    <style>
      .btn-func { padding: s-bind('@padding'); }
    </style>

    <button class="btn-func">
      FAKE FUNCTION BUTTON
    </button>
    """
  end
end
