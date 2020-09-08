defmodule Surface.Directive.ComponentProps do
  use Surface.Directive,
    extract: [
      name: ":props",
      type: :map
    ]

  def process(
        %AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta},
        %AST.Component{} = node
      ) do
    %{
      node
      | dynamic_props: %AST.DynamicAttribute{
          name: :props,
          meta: meta,
          expr: expr
        }
    }
  end
end
