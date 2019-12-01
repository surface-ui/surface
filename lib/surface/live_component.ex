defmodule Surface.LiveComponent do
  defmacro __using__(_) do
    quote do
      use Phoenix.LiveComponent
      use Surface.BaseComponent
      use Surface.EventValidator
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)

      def translator do
        Surface.Translator.LiveComponentTranslator
      end
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @optional_callbacks begin_context: 1, end_context: 1
end
