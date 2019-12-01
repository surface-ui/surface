defmodule Surface.Component do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
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
end
