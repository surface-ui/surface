defmodule Surface.RendererTest.Components do
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
