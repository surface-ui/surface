defmodule Surface.RendererTest.Components do
  defmodule ComponentWithExternalTemplate do
    use Surface.Component
  end

  defmodule ComponentWithExternalTemplateAndRenderSface do
    use Surface.Component

    def render(assigns) do
      assigns = assign(assigns, value: "render_sface")
      render_sface(assigns)
    end
  end

  defmodule LiveComponentWithExternalTemplate do
    use Surface.LiveComponent
  end

  defmodule LiveComponentWithExternalTemplateAndRenderSface do
    use Surface.LiveComponent

    def render(assigns) do
      assigns = assign(assigns, value: "render_sface")
      render_sface(assigns)
    end
  end

  defmodule LiveViewWithExternalTemplate do
    use Surface.LiveView
  end

  defmodule LiveViewWithExternalTemplateAndRenderSface do
    use Surface.LiveView

    def render(assigns) do
      assigns = assign(assigns, value: "render_sface")
      render_sface(assigns)
    end
  end
end
