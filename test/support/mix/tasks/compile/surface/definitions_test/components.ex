defmodule Mix.Tasks.Compile.Surface.DefinitionsTest.Components do
  defmodule Comp1 do
    use Surface.Component
    alias Enum, as: MyEnum, warn: false
    import Mix.Tasks.Compile.Surface.DefinitionsTest.PhoenixComponents, warn: false

    @moduledoc "My component docs"

    @doc "The label"
    prop label, :string, required: true

    def render(assigns), do: ~F[]

    attr(:name, :string)
    def func_with_attr(assigns), do: ~F[]

    attr(:name, :string)
    defp priv_func_with_attr(assigns), do: ~F[]

    def func_without_attr(assigns), do: ~F[]
  end

  defmodule Comp2 do
    use Surface.Component

    prop label2, :string
    prop class2, :css_class

    def render(assigns), do: ~F[]
  end
end
