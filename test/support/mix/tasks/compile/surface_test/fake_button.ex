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

  def func_without_inline_style(assigns) do
    ~F"""
    <button class="btn">
      FAKE BUTTON WITHOUT STYLE
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

  def inner_func(assigns) do
    ~F"""
    <style>
      .inner { padding: 2px; }
    </style>

    <button class={"inner"}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  def outer_func(assigns) do
    ~F"""
    <style>
      .outer { padding: 1px; }
    </style>

    <.inner_func>
      <span class="outer">Ok</span>
    </.inner_func>
    """
  end
end
