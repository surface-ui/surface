defmodule Surface.Directive.ComponentProps do
  use Surface.Directive

  def extract({":props", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :props,
      value: directive_value(value, expr_meta),
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta},
        %mod{} = node
      )
      when mod in [AST.Component, AST.SlotableComponent] do
    %{
      node
      | dynamic_props: %AST.DynamicAttribute{
          name: :props,
          meta: meta,
          expr: expr
        }
    }
  end

  defp directive_value(value, meta) do
    %AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(value, ":props", :map, meta),
      meta: meta
    }
  end
end
