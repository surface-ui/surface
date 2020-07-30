defmodule Surface.Directive do
  @callback extract(node :: any, meta :: Surface.AST.Meta.t()) ::
              [Surface.AST.Directive.t()]
              | Surface.AST.Directive.t()
  @callback process(node :: Surface.AST.t()) :: Surface.AST.t()

  defmacro __using__(_) do
    quote do
      alias Surface.AST
      alias Surface.Compiler.Helpers
      alias Surface.IOHelper

      @behaviour unquote(__MODULE__)

      # TODO: define default extract to handle base case?
    end
  end
end
