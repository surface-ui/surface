defmodule Surface.Directive do
  alias Surface.AST
  alias Surface.Compiler.Helpers
  alias Surface.IOHelper

  @callback extract(node :: any, meta :: Surface.AST.Meta.t()) ::
              [Surface.AST.Directive.t()]
              | Surface.AST.Directive.t()
  @callback handle_value(
              ast :: Surface.AST.Text.t() | Surface.AST.AttributeExpr.t(),
              meta :: Surface.AST.Meta.t()
            ) ::
              {:ok, Surface.AST.Text.t() | Surface.AST.AttributeExpr.t()} | {:error, binary()}
  @callback handle_modifier(
              ast :: Macro.t(),
              modifier :: binary(),
              meta :: Surface.AST.Meta.t()
            ) :: Surface.AST.Text.t() | Surface.AST.AttributeExpr.t()
  @callback process(directive :: Surface.AST.Directive.t(), node :: Surface.AST.t()) ::
              Surface.AST.t()

  @optional_callbacks process: 2, handle_modifier: 3

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
        |> Surface.Directive.extract_directive_value(meta, __MODULE__, @extract_opts)
        |> Surface.Directive.handle_directive_value(@extract_opts[:name], __MODULE__)
      end
    end
  end

  @doc false
  def extract_directive_value({attr_name, value, attr_meta}, meta, module, opts) do
    name = opts[:name]

    case String.split(attr_name, ".") do
      [^name | applied_modifiers] ->
        attr_meta = Helpers.to_meta(attr_meta, meta)

        ast =
          value
          |> to_ast!(name, opts[:type], attr_meta)
          |> handle_modifiers(
            attr_meta,
            applied_modifiers,
            opts[:modifiers] || [],
            module,
            opts[:name]
          )

        {ast, applied_modifiers, attr_meta}

      _ ->
        nil
    end
  end

  @doc false
  def handle_directive_value({ast, applied_modifiers, meta}, name, module) do
    case module.handle_value(ast, meta) do
      {:ok, ast} ->
        %AST.Directive{
          module: module,
          modifiers: applied_modifiers,
          name: String.to_atom(name),
          value: ast,
          meta: meta
        }

      {:error, message} ->
        IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  def handle_directive_value(_value, _name, _module), do: []

  defp handle_modifiers(value, _meta, [], _allowed, _module, _name), do: value

  defp handle_modifiers(
         %{value: clause} = ast,
         meta,
         [modifier | modifiers],
         allowed,
         module,
         name
       ) do
    if Enum.member?(allowed, modifier) do
      clause = module.handle_modifier(clause, modifier, meta)
      handle_modifiers(%{ast | value: clause}, meta, modifiers, allowed, module, name)
    else
      message = "unknown modifier \"#{modifier}\" for directive #{name}"
      IOHelper.compile_error(message, meta.file, meta.line)
    end
  end

  defp handle_modifiers(value, _meta, _applied, _allowed, _module, _name), do: value

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
