defmodule Surface.ComponentsCallsTest.Components do
  defmodule ComponentCall do
    use Surface.Component
    def render(assigns), do: ~F""
  end

  defmodule ComponentWithExternalTemplate do
    use Surface.Component
  end

  defmodule LiveComponentWithExternalTemplate do
    use Surface.LiveComponent
  end

  defmodule LiveViewWithExternalTemplate do
    use Surface.LiveView
  end
end
