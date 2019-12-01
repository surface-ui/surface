defmodule Surface.Component do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      import Surface.Translator, only: [sigil_H: 2]
      import unquote(__MODULE__), only: [component: 2, component: 3]
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)

      def translator do
        Surface.Translator.ComponentTranslator
      end
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @callback render(assigns :: map()) :: any
  @optional_callbacks begin_context: 1, end_context: 1

  def component(module, assigns) do
    module.render(assigns)
  end

  def component(module, assigns, []) do
    module.render(assigns)
  end
end
