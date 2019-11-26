defmodule Surface.LiveComponent do
  defmacro __using__(_) do
    quote do
      use Phoenix.LiveComponent
      use Surface.BaseComponent
      use Surface.EventValidator
      import Surface.Translator, only: [sigil_H: 2]
      import Surface.Component, only: [component: 2, component: 3]

      @behaviour unquote(__MODULE__)

      def __component_type__ do
        unquote(__MODULE__)
      end
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @optional_callbacks begin_context: 1, end_context: 1
end
