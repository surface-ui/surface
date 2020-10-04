defmodule Surface.Directive.Debug do
  use Surface.Directive

  def extract({":debug", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :debug,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract({":debug", _, attr_meta}, meta) do
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :debug,
      value: %AST.AttributeExpr{
        original: "",
        value: [:code],
        meta: attr_meta
      },
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{value: %AST.AttributeExpr{value: debug}}, %type{} = node) do
    node = %{node | debug: Keyword.merge(node.debug || [], debug)}

    if Enum.member?(node.debug, :ast) do
      IO.puts(">>> DEBUG(AST): #{node.meta.file}:#{node.meta.line}")
      IO.puts(inspect(node, pretty: true))
      IO.puts("<<<")
    end

    if type in [AST.VoidTag, AST.Tag, AST.Container] and Enum.member?(node.debug, :code) do
      %AST.If{
        condition: %AST.AttributeExpr{
          original: "generated from :debug",
          value: true,
          meta: node.meta
        },
        debug: node.debug,
        meta: node.meta,
        children: [node]
      }
    else
      node
    end
  end

  defp directive_value(value, meta) do
    expr = Surface.TypeHandler.expr_to_quoted!(value, ":debug", :static_list, meta)

    for name <- expr do
      if not is_atom(name) do
        invalid_debug_value!(value, meta)
      end
    end

    %AST.AttributeExpr{
      value: expr,
      original: value,
      meta: meta
    }
  end

  @spec invalid_debug_value!(any(), Surface.AST.Meta.t()) :: no_return()
  defp invalid_debug_value!(value, meta) do
    message = """
    invalid value for directive :debug. Expected a list of atoms, \
    got: #{String.trim(value)}.\
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end
end
