defmodule Surface.LiveView do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.EventValidator
      import Phoenix.HTML

      property id, :integer
      property session, :map

      def translator do
        Surface.Translator.LiveViewTranslator
      end

      use Phoenix.LiveView
    end
  end
end
