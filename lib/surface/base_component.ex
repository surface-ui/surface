defmodule Surface.BaseComponent do
  @moduledoc false

  @doc """
  Defines which module is responsible for translating the component. The
  returned module must implement the `Surface.Translator` behaviour.
  """
  @callback translator() :: module

  @doc """
  Declares which type of component this is. This is used to determine what
  validation should be applied at compile time for a module, as well as
  the rendering behaviour when this component is referenced.
  """
  @callback component_type() :: module()

  defmacro __using__(opts \\ []) do
    {translator, opts} = Keyword.pop!(opts, :translator)
    {type, _opts} = Keyword.pop!(opts, :type)

    quote do
      import Surface
      @behaviour unquote(__MODULE__)

      # TODO: Remove the alias after fix ElixirSense
      alias Module, as: Mod
      Mod.put_attribute(__MODULE__, :translator, unquote(translator))
      Mod.put_attribute(__MODULE__, :component_type, unquote(type))

      @doc false
      def component_type do
        unquote(type)
      end

      @doc false
      def translator do
        unquote(translator)
      end
    end
  end
end
