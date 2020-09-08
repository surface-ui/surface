defmodule Surface.Directive do
  @callback extract(node :: any, meta :: Surface.AST.Meta.t()) ::
              [Surface.AST.Directive.t()]
              | Surface.AST.Directive.t()
  @callback process(directive :: Surface.AST.Directive.t(), node :: Surface.AST.t()) ::
              Surface.AST.t()

  @optional_callbacks process: 2

  defmacro __using__(opts) do
    quote do
      alias Surface.AST
      alias Surface.Compiler.Helpers
      alias Surface.IOHelper

      @behaviour unquote(__MODULE__)

      unquote(extract_function(opts[:extract]))

      def handle_value(attr, _), do: {:ok, attr}
      defoverridable handle_value: 2
    end
  end

  def extract_function(nil) do
    quote do
    end
  end

  def extract_function(opts) do
    name = opts[:name]
    atom_name = String.to_atom(name)
    type = opts[:type]

    quote do
      def extract({unquote(name), {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
        expr_meta = Helpers.to_meta(expr_meta, meta)
        attr_meta = Helpers.to_meta(attr_meta, meta)

        expr = Surface.TypeHandler.expr_to_quoted!(value, unquote(name), unquote(type), expr_meta)

        case handle_value(expr, expr_meta) do
          {:ok, expr} ->
            %AST.Directive{
              module: __MODULE__,
              name: unquote(atom_name),
              value: %AST.AttributeExpr{
                original: value,
                value: expr,
                meta: meta
              },
              meta: attr_meta
            }

          {:error, message} ->
            IOHelper.compile_error(message, meta.file, meta.line)
        end
      end

      def extract({unquote(name), value, attr_meta}, meta) do
        attr_meta = Helpers.to_meta(attr_meta, meta)

        ast =
          Surface.TypeHandler.literal_to_ast_node!(
            unquote(name),
            unquote(type),
            value,
            attr_meta
          )

        case handle_value(ast, meta) do
          {:ok, expr} ->
            %AST.Directive{
              module: __MODULE__,
              name: unquote(atom_name),
              value: expr,
              meta: attr_meta
            }

          {:error, message} ->
            IOHelper.compile_error(message, meta.file, meta.line)
        end
      end

      def extract(_, _), do: []

      defoverridable extract: 2
    end
  end
end
