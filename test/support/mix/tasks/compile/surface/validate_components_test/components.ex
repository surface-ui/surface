defmodule Mix.Tasks.Compile.Surface.ValidateComponentsTest.Components do
  defmodule ComponentCall do
    use Surface.Component
    prop value, :string, required: true
    def render(assigns), do: ~F"{@value}"
  end

  defmodule LiveViewWithExternalTemplate do
    use Surface.LiveView
  end
end
