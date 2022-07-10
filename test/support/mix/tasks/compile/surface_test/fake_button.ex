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
    assigns =
      assigns
      |> assign(:padding, "10px")
      |> assign(:color, "red")

    ~F"""
    <style>
      .btn-func { padding: s-bind('@padding'); color: s-bind('@color'); }
    </style>

    <button class="btn-func">
      FAKE FUNCTION BUTTON
    </button>
    """
  end
end
