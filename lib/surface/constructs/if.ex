defmodule Surface.Constructs.If do
  @moduledoc """
  Provides both a directive named `:if` as well as a construct named `If` (for wrapping multiple elements in an if expression).

  ## Examples
  ```
  <a :if={{ @display_link }} href={{ @item.to }}>{{ @item.label }}</a>
  ```

  ```
  <If condition={{ @display_link }}>
    <Icon name="cheveron_left" />
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

  def process(directive, node) do
    %AST.Directive{value: expr, meta: meta} = directive

    %AST.If{condition: expr, children: [node], meta: meta}
  end
end
