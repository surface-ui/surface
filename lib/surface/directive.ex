defmodule Surface.Directive do
  alias Surface.AST
  alias Surface.Compiler.Helpers

  @callback extract(node :: any, meta :: Surface.AST.Meta.t()) ::
              [Surface.AST.Directive.t()]
              | Surface.AST.Directive.t()
  @callback handle_value(
              ast :: Surface.AST.Text.t() | Surface.AST.AttributeExpr.t(),
              meta :: Surface.AST.Meta.t()
            ) ::
              {:ok, Surface.AST.Text.t() | Surface.AST.AttributeExpr.t()} | {:error, binary()}
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

      defoverridable handle_value: 2, extract: 2
    end
  end

  def extract_function(nil) do
    quote do
      def extract(_, _), do: []
    end
  end

  def extract_function(opts) do
    quote do
      @extract_opts unquote(opts)

      def extract(attr, meta) do
        attr
        |> Surface.Directive.extract_directive(meta, @extract_opts[:name], @extract_opts[:type])
        |> case do
          {ast, directive_meta} -> handle_value(ast, directive_meta)
          _ -> :empty
        end
        |> case do
          :empty ->
            []

          {:ok, ast} ->
            %AST.Directive{
              module: __MODULE__,
              name: String.to_atom(@extract_opts[:name]),
              value: ast,
              meta: meta
            }

          {:error, message} ->
            IOHelper.compile_error(message, meta.file, meta.line)
        end
      end
    end
  end

  @doc false
  def extract_directive({attr_name, value, attr_meta}, meta, name, type) when attr_name == name do
    # expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    ast = to_ast!(value, name, type, attr_meta)

    {ast, attr_meta}
  end

  def extract_directive(_attr, _meta, _name, _type), do: nil

  defp to_ast!({:attribute_expr, value, expr_meta}, name, type, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)

    %AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(value, name, type, expr_meta),
      meta: expr_meta
    }
  end

  defp to_ast!(value, name, type, meta) do
    Surface.TypeHandler.literal_to_ast_node!(type, name, value, meta)
  end
end
