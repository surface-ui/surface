defmodule Surface.MacroComponent do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent

      @behaviour Surface.Translator

      def translator do
        __MODULE__
      end
    end
  end
end
