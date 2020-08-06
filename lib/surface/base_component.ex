defmodule Surface.BaseComponent do
  @moduledoc false

  @doc """
  Declares which type of component this is. This is used to determine what
  validation should be applied at compile time for a module, as well as
  the rendering behaviour when this component is referenced.
  """
  @callback component_type() :: module()

  defmacro __using__(opts \\ []) do
    {type, _opts} = Keyword.pop!(opts, :type)

    quote do
      import Surface
      @behaviour unquote(__MODULE__)

      # TODO: Remove the alias after fix ElixirSense
      alias Module, as: Mod
      Mod.put_attribute(__MODULE__, :component_type, unquote(type))

      @doc false
      def component_type do
        unquote(type)
      end
    end
  end
end
