defmodule Mix.Tasks.Compile.SurfaceTest.FakeButtonWithVariant do
  use Surface.Component

  prop loading?, :boolean, css_variant: true
  prop rounded, :boolean, css_variant: true
  prop status, :string, values: ["on", "off"], css_variant: true
  data live, :boolean, css_variant: true
  data visible, :boolean, css_variant: true
  data size!, :string, values: ["small", "large"], css_variant: true
  data items, :list, css_variant: true
  data empty_items, :list, css_variant: true
  data nil_items, :list, css_variant: true
  data dynamic, :string

  def render(assigns) do
    assigns =
      assigns
      |> assign(:visible, false)
      |> assign(:live, true)
      |> assign(:size!, "small")
      |> assign(:items, ["a", "b"])
      |> assign(:empty_items, [])
      |> assign(:nil_items, nil)
      |> assign(:dynamic, "dynamic")

    ~F"""
    <button>
      <span>no scope</span>
      <span class="class-not-using-variants">no scope</span>
      <span class="live:text-xs">with scope</span>
      <span class="visible:text-xs">with scope</span>
      <span class="status-on:text-xs">with scope</span>
      <span class="size-small:text-xs">with scope</span>
      <span class="has-items:block">with scope</span>
      <span class="no-empty-items:hidden">with scope</span>
      <span class="no-nil-items:hidden">with scope</span>
      <span class={@dynamic}>with scope</span>
    </button>
    """
  end
end
