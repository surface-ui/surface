defmodule Mix.Tasks.Compile.SurfaceTest.FakeButtonWithVariant do
  use Surface.Component

  prop prop_true, :boolean, css_variant: true
  prop prop_false, :boolean, css_variant: true
  prop prop_values, :string, values: ["on", "off"], css_variant: true
  data data_true, :boolean, css_variant: true
  data data_false, :boolean, css_variant: true
  data data_values!, :string, values: ["small", "large"], css_variant: true
  data items, :list, css_variant: true
  data empty_items, :list, css_variant: true
  data nil_items, :list, css_variant: true
  data dynamic, :string

  def render(assigns) do
    assigns =
      assigns
      |> assign(:data_false, false)
      |> assign(:data_true, true)
      |> assign(:data_true, true)
      |> assign(:data_values!, "small")
      |> assign(:items, ["a", "b"])
      |> assign(:empty_items, [])
      |> assign(:nil_items, nil)
      |> assign(:dynamic, "dynamic")

    ~F"""
    <button>
      <span>no scope</span>
      <span class="class-not-using-variants">no scope</span>
      <span class="data-true:text-xs">with scope</span>
      <span class="data-false:text-xs">with scope</span>
      <span class="prop-values-small:text-xs">with scope</span>
      <span class="data-values-small:text-xs">with scope</span>
      <span class="has-items:block">with scope</span>
      <span class="no-empty-items:hidden">with scope</span>
      <span class="no-nil-items:hidden">with scope</span>
      <span class={@dynamic}>with scope</span>
    </button>
    """
  end
end
