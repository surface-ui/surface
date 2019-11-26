defmodule Surface.MacroComponent do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      import Surface.Translator, only: [sigil_H: 2]

      @behaviour unquote(__MODULE__)

      def __component_type__ do
        unquote(__MODULE__)
      end
    end
  end

  @callback translate(node :: any, caller: any) :: any
end
