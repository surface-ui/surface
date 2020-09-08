defmodule Surface.Directive.If do
  use Surface.Directive,
    extract: [
      name: ":if",
      type: :boolean
    ]

  def process(%AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta}, node),
    do: %AST.If{condition: expr, children: [node], meta: meta}
end
