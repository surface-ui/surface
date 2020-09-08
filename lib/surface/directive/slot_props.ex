defmodule Surface.Directive.SlotProps do
  use Surface.Directive,
    extract: [
      name: ":props",
      type: :keyword
    ]

  def process(%AST.Directive{value: %AST.AttributeExpr{value: value}}, %AST.Slot{} = slot) do
    %{slot | props: value}
  end
end
