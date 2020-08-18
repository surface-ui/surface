defmodule Surface.Directive.SlotProps do
  use Surface.Directive

  def extract({":props", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :props,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  defp directive_value(value, meta) do
    %AST.AttributeExpr{
      value: Helpers.attribute_expr_to_quoted!(value, ":props", :keyword, meta),
      original: value,
      meta: meta
    }
  end
end
