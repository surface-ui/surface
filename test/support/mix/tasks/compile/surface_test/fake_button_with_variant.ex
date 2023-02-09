defmodule Mix.Tasks.Compile.SurfaceTest.FakeButtonWithVariant do
  use Surface.Component

  prop prop_true, :boolean, css_variant: true
  prop prop_false, :boolean, css_variant: true
  data data_true, :boolean, css_variant: true
  data data_false, :boolean, css_variant: true
  data dynamic, :string

  def render(assigns) do
    assigns =
      assigns
      |> assign(:data_false, false)
      |> assign(:data_true, true)
      |> assign(:data_true, true)
      |> assign(:dynamic, "dynamic")

    ~F"""
    <button>
      <span>no scope</span>
      <span class="class-not-using-variants">no scope</span>
      <span class="data_true:text-xs">with scope</span>
      <span class="data_false:text-xs">with scope</span>
      <span class={@dynamic}>with scope</span>
    </button>
    """
  end
end
