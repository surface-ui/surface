defmodule Surface.Components.Dynamic.Component do
  @moduledoc """
  A built-in component that allows users to inject dynamic components into
  a Surface template.
  """

  use Surface.Component

  alias Surface.AST

  @doc """
  The module of the component
  """
  prop module, :module, required: true

  @doc """
  The function of the component
  """
  prop function, :atom

  @doc """
  The default slot
  """
  slot default

  @doc false
  def transform(node) do
    %AST.Component{props: props, directives: directives, slot_entries: slot_entries, meta: meta} = node

    {%{module: mod, function: fun}, other_props} = AST.pop_attributes_values_as_map(props, [:module, :function])

    %AST.FunctionComponent{
      module: mod,
      fun: fun,
      type: :dynamic,
      props: other_props,
      directives: directives,
      slot_entries: slot_entries,
      meta: meta
    }
  end

  def render(assigns), do: ~F[]
end
