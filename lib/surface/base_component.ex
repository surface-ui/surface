defmodule Surface.BaseComponent do
  @moduledoc false

  @doc """
  Defines which module is responsible for translating the component. The
  returned module must implement the `Surface.Translator` behaviour.
  """
  @callback translator() :: module

  defmacro __using__(translator: translator) do
    quote do
      import Surface
      @behaviour unquote(__MODULE__)

      # TODO: Remove the alias after fix ElixirSense
      alias Module, as: Mod
      Mod.put_attribute(__MODULE__, :translator, unquote(translator))

      @doc false
      def translator do
        unquote(translator)
      end
    end
  end
end
