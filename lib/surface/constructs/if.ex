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
  use Surface.Component

  alias Surface.AST

  @doc "The condition for the if expression"
  prop condition, :boolean, required: true
  slot default, required: true

  def render(_), do: ""

  def transform(node) do
    condition =
      Enum.find_value(
        node.props,
        %AST.AttributeExpr{value: false, original: "", meta: node.meta},
        fn prop ->
          if prop.name == :condition do
            prop.value
          end
        end
      )

    children =
      if Enum.empty?(node.templates.default),
        do: [],
        else: List.first(node.templates.default).children

    %AST.If{
      condition: condition,
      children: children,
      meta: node.meta
    }
  end
end
