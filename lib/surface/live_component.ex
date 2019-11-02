defmodule Surface.LiveComponent do
  defmacro __using__(_) do
    quote do
      use Phoenix.LiveComponent
      use Surface.BaseComponent
      use Surface.EventValidator
      import Surface.Translator, only: [sigil_H: 2]

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      def render_code(node, caller) do
        opts = [renderer: "live_component", pass_socket: true, assigns_as_keyword: true]
        Surface.Translator.DefaultComponentTranslator.translate(node, caller, opts)
      end

      defoverridable render_code: 2
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @optional_callbacks begin_context: 1, end_context: 1
end
