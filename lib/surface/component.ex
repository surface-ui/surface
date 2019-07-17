defmodule Surface.Component do
  alias Surface.Properties

  defmodule DataContent do
    defstruct [:data, :component]
  end

  defmacro __using__(_) do
    quote do
      use Surface.Properties

      import unquote(__MODULE__)
      import Surface.Parser
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)

      def __component_type() do
        unquote(__MODULE__)
      end
    end
  end

  @callback render(props :: map(), content :: any) :: any

  def children_by_type(block, component) do
    {:safe, content} = block
    for %DataContent{data: data, component: ^component} <- content do
      data
    end
  end

  def render_call(mod_str, attributes, mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    ["render_component(", mod_str, ", ", rendered_props, ")"]
  end

  def render_component(module, props) do
    do_render_component(module, props, [])
  end

  def render_component(module, props, do: block) do
    do_render_component(module, props, block)
  end

  defp do_render_component(module, props, content) do
    case module.render(props, content) do
      {:data, data} ->
        %DataContent{data: data, component: module}
      result ->
        result
    end
  end
end

defimpl Phoenix.HTML.Safe, for: Surface.Component.DataContent do
  def to_iodata(data) do
    data
  end
end
