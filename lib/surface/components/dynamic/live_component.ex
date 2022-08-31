defmodule Surface.Components.Dynamic.LiveComponent do
  @moduledoc """
  A built-in component that allows users to inject dynamic live components into
  a Surface template.
  """

  use Surface.LiveComponent

  alias Surface.AST

  @doc """
  The module of the component
  """
  prop module, :module, required: true

  @doc """
  The default slot
  """
  slot default

  @doc false
  def transform(node) do
    %AST.Component{props: props, directives: directives, slot_entries: slot_entries, meta: meta} = node

    {%{module: mod}, other_props} = AST.pop_attributes_values_as_map(props, [:module])

    %AST.Component{
      module: mod,
      type: :dynamic_live,
      props: other_props,
      directives: directives,
      slot_entries: slot_entries,
      meta: meta
    }
  end

  def render(assigns), do: ~F[<div/>]
end
