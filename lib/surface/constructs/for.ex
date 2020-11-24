defmodule Surface.Constructs.For do
  @moduledoc """
  Provides an alternative to the `:for` directive for wrapping multiple elements in a for loop.

  ## Examples
  ```
  <For each={{ item <- @items }}>
    <a href={{ item.to }}>{{ item.label }}</a>
    <Icon name="cheveron_left" />
  </For>
  ```
  """
  use Surface.Component

  alias Surface.AST

  @doc "The generator for the for expression"
  prop each, :generator, required: true
  slot default, required: true

  def render(_), do: ""

  def transform(node) do
    generator =
      Enum.find_value(
        node.props,
        %AST.AttributeExpr{value: [], original: "", meta: node.meta},
        fn prop ->
          if prop.name == :each do
            prop.value
          end
        end
      )

    children =
      if Enum.empty?(node.templates.default),
        do: [],
        else: List.first(node.templates.default).children

    %AST.For{
      generator: generator,
      children: children,
      meta: node.meta
    }
  end
end
