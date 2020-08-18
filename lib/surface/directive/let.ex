defmodule Surface.Directive.Let do
  use Surface.Directive

  def extract({":let", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :let,
      value: directive_value(value, Map.merge(meta, expr_meta)),
      meta: Map.merge(meta, attr_meta)
    }
  end

  def extract(_, _), do: []

  defp directive_value(value, meta) do
    %AST.AttributeExpr{
      value: Helpers.attribute_expr_to_quoted!(value, ":let", :bindings, meta),
      original: value,
      meta: meta
    }
  end
end
