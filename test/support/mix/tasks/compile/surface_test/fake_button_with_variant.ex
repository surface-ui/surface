defmodule Mix.Tasks.Compile.SurfaceTest.FakeButtonWithVariant do
  use Surface.Component

  # Boolean
  prop visible, :boolean, css_variant: true

  # Boolean with custom `false` variant name
  prop active, :boolean, css_variant: [false: "inactive"]

  # Boolean with custom `true` and `false` variant names
  prop dark?, :boolean, css_variant: [true: "is-dark", false: "is-light"]

  # Choice :string
  data size, :string, values: ["small", "large"], css_variant: true

  # Choice :string values with custom variant prefix
  data status, :string, values: ["on", "off"], css_variant: [prefix: ""]

  # Enumerable
  data items, :list, css_variant: true
  data empty_items, :list, css_variant: true
  data nil_items, :list, css_variant: true
  data map, :map, css_variant: true
  data keyword, :keyword, css_variant: true
  data mapset, :mapset, css_variant: true

  # Other types
  data other, :any, css_variant: true

  # Enumerable with custom variant names
  data errors, :list, css_variant: [has_items: "invalid", no_items: "valid"]

  data dynamic, :string

  def render(assigns) do
    assigns =
      assigns
      |> assign(:size, "small")
      |> assign(:status, "on")
      |> assign(:items, ["a", "b"])
      |> assign(:empty_items, [])
      |> assign(:nil_items, nil)
      |> assign(:map, %{a: 1, b: 2})
      |> assign(:keyword, a: 1, b: 2)
      |> assign(:mapset, MapSet.new([1]))
      |> assign(:errors, [])
      |> assign(:other, "other")
      |> assign(:dynamic, "dynamic")

    ~F"""
    <button>
      <span>no scope</span>
      <span class="class-not-using-variants">no scope</span>
      <span class="@visible:block">with scope</span>
      <span class="@not-visible:block">with scope</span>
      <span class="@active:block">with scope</span>
      <span class="@inactive:block">with scope</span>
      <span class="@is-dark:block">with scope</span>
      <span class="@is-light:block">with scope</span>
      <span class="@size-small:block">with scope</span>
      <span class="@on:block">with scope</span>
      <span class="@off:block">with scope</span>
      <span class="@has-items:block">with scope</span>
      <span class="@no-items:block">with scope</span>
      <span class="@has-map:block">with scope</span>
      <span class="@no-map:block">with scope</span>
      <span class="@has-keyword:block">with scope</span>
      <span class="@no-keyword:block">with scope</span>
      <span class="@has-mapset:block">with scope</span>
      <span class="@no-mapset:block">with scope</span>
      <span class="@valid:block">with scope</span>
      <span class="@invalid:block">with scope</span>
      <span class="@other:block">with scope</span>
      <span class="@no-other:block">with scope</span>
      <span class={@dynamic}>with scope</span>
    </button>
    """
  end
end
