defmodule Surface.Directive do
  @callback matches?(type :: module(), attribute_name :: :root | binary()) :: boolean()
  @callback type() :: atom()
  @callback extract(node :: any, meta :: Surface.AST.Meta.t()) ::
              [Surface.AST.Directive.t()]
              | Surface.AST.Directive.t()
  @callback process(directive :: Surface.AST.Directive.t(), node :: Surface.AST.t()) ::
              Surface.AST.t()
  @callback process(
              name :: name(),
              value :: Surface.AST.AttributeExpr.t() | Surface.AST.Literal.t() | nil,
              meta :: Surface.AST.Meta.t(),
              node :: Surface.AST.t()
            ) :: Surface.AST.t()

  @optional_callbacks process: 2, process: 4

  defstruct [:module, :name, :original_name, :value, :meta]

  @type name :: atom() | binary()
  @type t :: %__MODULE__{
          module: atom(),
          name: name(),
          original_name: binary(),
          # the value here is defined by the individual directive
          value: Surface.AST.AttributeExpr.t() | Surface.AST.Literal.t() | nil,
          meta: Surface.AST.Meta.t()
        }

  defmacro __using__(_) do
    quote do
      alias Surface.AST
      alias Surface.Compiler.Helpers
      alias Surface.IOHelper

      @behaviour unquote(__MODULE__)

      def matches?(_, _), do: false
      def type(), do: :any

      defoverridable matches?: 2, type: 0
    end
  end

  def normalize_name(":" <> name), do: name
  def normalize_name("s-" <> name), do: name
  def normalize_name(name), do: name
end
