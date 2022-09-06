defmodule Surface.Directive.Let do
  use Surface.Directive

  def extract({":let", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :let,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{value: value}, %AST.Component{} = node) do
    update_in(node.slot_entries, fn
      %{default: [first | others]} = tpls ->
        Map.put(tpls, :default, [%{first | let: value} | others])

      tpls ->
        tpls
    end)
  end

  def process(%AST.Directive{value: value}, %type{} = node)
      when type in [AST.SlotEntry, AST.SlotableComponent] do
    %{node | let: value}
  end

  def process(_, node), do: node

  defp directive_value(value, meta) do
    AST.AttributeExpr.new(
      Surface.TypeHandler.expr_to_quoted!(value, ":let", :let_arg, meta),
      value,
      meta
    )
  end
end
