defmodule Surface.Directive.Let do
  use Surface.Directive,
    extract: [
      name: ":let",
      type: :bindings
    ]

  def process(%AST.Directive{value: %AST.AttributeExpr{value: value}}, %{let: let} = node) do
    %{node | let: [value | let]}
  end
end
