defmodule Surface.Constructs.If do
  @moduledoc """
  Provides an alternative to the `:if` directive for wrapping multiple elements in an if expression.

  ## Examples
  ```
  <If condition={{ @display_link }}>
    <Icon name="cheveron_left" />
    <a href={{ @item.to }}>{{ @item.label }}</a>
  </If>
  ```
  """
  use Surface.Construct,
    name: :if,
    type: :boolean,
    directive: true,
    component: [
      prop: [
        name: condition,
        default: false
      ]
    ]

  alias Surface.AST

  def process(directive, node) do
    %AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta} = directive

    %AST.If{condition: expr, children: [node], meta: meta}
  end
end
