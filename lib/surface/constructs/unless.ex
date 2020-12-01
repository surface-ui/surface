defmodule Surface.Constructs.Unless do
  @moduledoc """
  Provides an alternative to the `:unless` directive for wrapping multiple elements in an unless expression.

  ## Examples
  ```
  <Unless condition={{ @hide_link }}>
    <Icon name="cheveron_left" />
    <a href={{ @item.to }}>{{ @item.label }}</a>
  </Unless>
  ```
  """
  use Surface.Component

  alias Surface.AST

  @doc "The condition for the unless expression"
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

    %AST.Unless{
      condition: condition,
      children: children,
      meta: node.meta
    }
  end
end
