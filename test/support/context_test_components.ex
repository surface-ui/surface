defmodule Surface.ContextTest.Components do
  defmodule ComponentWithExternalTemplateUsingContext do
    use Surface.Component

    alias Surface.Components.ContextTest.Outer

    def render(assigns) do
      assigns = Context.copy_assign(assigns, {Outer, :field})
      render_sface(assigns)
    end
  end
end
