defmodule Surface.Directive.For do
  use Surface.Directive

  def extract({":for", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :for,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta}, node),
    do: %AST.Comprehension{generator: expr, children: [node], meta: meta}

  defp directive_value(value, meta) do
    %AST.AttributeExpr{
      original: value,
      value: Helpers.attribute_expr_to_quoted!(value, :generator, meta),
      meta: meta
    }
  end
end
