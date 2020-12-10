defmodule Surface.Directive do
  alias Surface.AST
  alias Surface.Compiler.Helpers
  alias Surface.IOHelper

  @callback extract(node :: any, meta :: AST.Meta.t()) ::
              [AST.Directive.t()]
              | AST.Directive.t()
  @callback process(directive :: AST.Directive.t(), node :: AST.t()) ::
              AST.t()
  @callback apply_modifier(
              modifier :: binary(),
              clause :: Macro.t(),
              expr_meta :: AST.Meta.t()
            ) :: Macro.t()

  @optional_callbacks process: 2, apply_modifier: 3

  defmacro __using__(opts \\ []) do
    quote do
      alias Surface.AST
      alias Surface.Compiler.Helpers
      alias Surface.IOHelper

      @behaviour unquote(__MODULE__)

      unquote(maybe_define_extract(Map.new(opts)))

      def update_value(node, _), do: {:ok, node}

      defoverridable update_value: 2
    end
  end

  def split_name_and_modifiers(attribute_name) do
    [name | applied_modifiers] = String.split(attribute_name, ".")

    {name, applied_modifiers}
  end

  @spec parse_attribute_value(
          parsed :: any(),
          name :: atom(),
          type :: atom(),
          meta :: AST.Meta.t()
        ) ::
          {AST.Literal.t() | AST.AttributeExpr.t(), AST.Meta.t()}
  def parse_attribute_value({:attribute_expr, value, parsed_expr_meta}, name, type, attr_meta) do
    expr_meta = Helpers.to_meta(parsed_expr_meta, attr_meta)

    expr =
      %AST.AttributeExpr{
        original: value,
        value: Surface.TypeHandler.expr_to_quoted!(value, name, type, expr_meta),
        meta: expr_meta
      }

    {expr, expr_meta}
  end

  def parse_attribute_value(literal, name, type, attr_meta) do
    value = Surface.TypeHandler.literal_to_ast_node!(type, name, literal, attr_meta)

    {value, attr_meta}
  end

  @spec apply_modifiers(
          value :: {AST.Literal.t() | AST.AttributeExpr.t(), AST.Meta.t()},
          applied_modifiers :: list(binary()),
          allowed_modifiers :: list(binary()),
          type :: atom(),
          name :: atom()
        ) ::
          {AST.Literal.t() | AST.AttributeExpr.t(), AST.Meta.t()}
  def apply_modifiers(
        {%{value: ast} = node, meta},
        modifiers,
        allowed,
        module,
        name
      ) do
    unknown = modifiers -- allowed

    if not Enum.empty?(unknown) do
      message = "unknown modifier \"#{List.first(unknown)}\" for directive #{name}"
      IOHelper.compile_error(message, meta.file, meta.line)
    end

    updated_ast =
      Enum.reduce(modifiers, ast, fn modifier, clause ->
        module.apply_modifier(modifier, clause, meta)
      end)

    {%{node | value: updated_ast}, meta}
  end

  def update_value({value, meta}, module) do
    case module.update_value(value, meta) do
      {:ok, value} -> {value, meta}
      {:error, message} -> IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  def create_directive({value, meta}, module, name) do
    %AST.Directive{
      module: module,
      name: name,
      value: value,
      meta: meta
    }
  end

  defp maybe_define_extract(%{
         pattern: pattern,
         type: type,
         modifiers: allowed_modifiers
       }) do
    quote do
      def extract(
            {":" <> attr_name, attr_value, parsed_attr_meta},
            compile_meta
          ) do
        {name, modifiers} = unquote(__MODULE__).split_name_and_modifiers(attr_name)

        if match?(unquote(pattern), name) do
          attr_meta = Helpers.to_meta(parsed_attr_meta, compile_meta)

          directive_name = String.to_atom(name)

          value =
            attr_value
            |> unquote(__MODULE__).parse_attribute_value(directive_name, unquote(type), attr_meta)
            |> unquote(__MODULE__).apply_modifiers(
              modifiers,
              unquote(allowed_modifiers),
              unquote(type),
              directive_name
            )
            |> unquote(__MODULE__).update_value(__MODULE__)
            |> unquote(__MODULE__).create_directive(__MODULE__, directive_name)
        else
          []
        end
      end

      def extract(_, _), do: []
    end
  end

  defp maybe_define_extract(_) do
    quote do
    end
  end
end
