defmodule Surface.Components.Component do
  @moduledoc """
  A built-in component that allows users to inject dynamic components into
  a Surface template.
  """

  use Surface.Component

  alias Surface.AST

  @doc """
  The module of the component
  """
  prop module, :module

  @doc """
  The function of the component
  """
  prop function, :atom

  @doc """
  The default slot
  """
  slot default

  def transform(node) do
    %AST.Component{props: props, directives: directives, templates: templates, meta: meta} = node

    {module_value, other_props} =
      props
      |> Enum.split_with(fn %AST.Attribute{name: name} -> name == :module end)
      |> case do
        {[%AST.Attribute{value: value} | _], rest} -> {value, rest}
        props -> {nil, props}
      end

    %AST.FunctionComponent{
      module: module_value,
      fun: :render,
      type: :remote,
      props: other_props,
      directives: directives,
      templates: templates,
      meta: meta
    }
  end

  def render(assigns), do: ~F[]
end
