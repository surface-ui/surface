defmodule Surface.Directive.If do
  use Surface.Directive,
    pattern: "if",
    type: :boolean

  def process(%AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta}, node),
    do: %AST.If{condition: expr, children: [node], meta: meta}
end
