defmodule Surface.BaseComponent do
  @moduledoc false

  @doc """
  Declares which type of component this is. This is used to determine what
  validation should be applied at compile time for a module, as well as
  the rendering behaviour when this component is referenced.
  """
  @callback component_type() :: module()

  @doc """
  This function will be invoked with parsed AST node as the only argument. The result
  will replace the original node in the AST.

  This callback is invoked before directives are handled for this node, but after all
  children of this node have been fully processed.
  """
  @callback transform(node :: Surface.AST.t()) :: Surface.AST.t()

  @optional_callbacks transform: 1

  defmacro __using__(opts) do
    type = Keyword.fetch!(opts, :type)

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

  @doc false
  def restore_private_assigns(socket, %{__surface__: surface, __context__: context}) do
    socket
    |> Phoenix.LiveView.assign(:__surface__, surface)
    |> Phoenix.LiveView.assign(:__context__, context)
  end

  def restore_private_assigns(socket, _assigns) do
    socket
  end
end
