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

  defstruct [:module, :name, :original_name, :value, :modifiers, :meta]

  @type name :: atom() | binary()
  @type t :: %__MODULE__{
          module: atom(),
          name: name(),
          original_name: binary(),
          modifiers: list(binary()),
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

  @doc """
  Extracts the directive name and any modifiers specified from an attribute name. The first
  element is the normalized directive name (or nil if the specified name does not begin with
  a valid prefix). The second element is the list of modifiers added to the directive.
  """
  @spec name_and_modifiers(name :: binary()) :: {nil | binary(), list(binary())}
  def name_and_modifiers(":" <> name), do: extract_modifiers(name)
  def name_and_modifiers("s-" <> name), do: extract_modifiers(name)
  def name_and_modifiers(_name), do: {nil, []}

  defp extract_modifiers(name) do
    case String.split(name, ".") do
      [name] ->
        {name, []}

      [name | modifiers] ->
        {name, modifiers}
    end
  end
end
