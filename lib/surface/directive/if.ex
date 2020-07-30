defmodule Surface.Directive.If do
  @behaviour Surface.Directive

  def extract({":if", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %Surface.AST.Directive{
      module: __MODULE__,
      name: :if,
      value: directive_value(value, Map.merge(meta, expr_meta)),
      meta: Map.merge(meta, attr_meta)
    }
  end

  def extract(_, _), do: []

  def process(node), do: node

  defp directive_value(value, meta) do
    expr = Code.string_to_quoted!(value, file: meta.file, line: meta.line)

    %Surface.AST.AttributeExpr{
      original: value,
      value: expr,
      meta: meta
    }
  end
end
