defmodule Surface.Directive.For do
  use Surface.Directive,
    extract: [
      name: ":for",
      type: :generator
    ]

  def process(%AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta}, node),
    do: %AST.For{generator: expr, children: [node], meta: meta}
end
