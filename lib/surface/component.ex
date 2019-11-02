defmodule Surface.Component do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.EventValidator
      alias Surface.Translator.DefaultComponentTranslator
      import Surface.Translator, only: [sigil_H: 2]

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      def render_code(node, caller) do
        opts = [renderer: "Surface.ComponentRenderer.render", pass_socket: false]
        DefaultComponentTranslator.translate(node, caller, opts)
      end

      defoverridable render_code: 2
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @callback render(assigns :: map()) :: any
  @optional_callbacks begin_context: 1, end_context: 1
end
