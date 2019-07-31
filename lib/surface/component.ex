defmodule Surface.Component do
  alias Surface.Properties

  defmodule DataContent do
    defstruct [:data, :component]
  end

  defmodule Lazy do
    defstruct [:func]
  end

  defmacro __using__(_) do
    quote do
      use Surface.Properties

      import unquote(__MODULE__)
      import Surface.Parser
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)
      @behaviour Surface.BaseComponent

      defdelegate render_code(mod_str, attributes, children_iolist, mod, caller),
        to: unquote(__MODULE__).CodeRenderer

      defoverridable render_code: 5
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @callback render(props :: map(), content :: any) :: any

  @optional_callbacks begin_context: 1, end_context: 1

  def lazy(func) do
    %Surface.Component.Lazy{func: func}
  end

  def non_empty_children([]) do
    []
  end

  def non_empty_children(block) do
    {:safe, content} = block
    for child <- content, !is_binary(child) || String.trim(child) != "" do
      child
    end
  end

  def children_by_type(block, component) do
    {:safe, content} = block
    for %DataContent{data: data, component: ^component} <- content do
      data
    end
  end

  def pop_children_by_type(block, component) do
    {:safe, content} = block
    {children, rest} = Enum.reduce(content, {[], []}, fn child, {children, rest} ->
      case child do
        %DataContent{data: data, component: ^component} ->
          {[data|children], rest}
        _ ->
          {children, [child|rest]}
      end
    end)
    {Enum.reverse(children), {:safe, Enum.reverse(rest)}}
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

  defmodule CodeRenderer do
    def render_code(mod_str, attributes, [], mod, caller) do
      rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
      ["<%= render_component(", mod_str, ", ", rendered_props, ") %>"]
    end

    def render_code(mod_str, attributes, children_iolist, mod, caller) do
      rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
      [
        maybe_add_begin_context(mod, mod_str, rendered_props),
        "<%= render_component(", mod_str, ", ", rendered_props, ") do %>\n",
        children_iolist,
        "<% end %>\n",
        maybe_add_end_context(mod, mod_str, rendered_props)
      ]
    end

    defp maybe_add_begin_context(mod, mod_str, rendered_props) do
      if function_exported?(mod, :begin_context, 1) do
        ["<% context = ", mod_str, ".begin_context(", rendered_props, ") %>\n<% _ = context %>\n"]
      else
        ""
      end
    end

    defp maybe_add_end_context(mod, mod_str, rendered_props) do
      if function_exported?(mod, :end_context, 1) do
        ["<% context = ", mod_str, ".end_context(", rendered_props, ") %>\n<% _ = context %>\n"]
      else
        ""
      end
    end
  end
end

defimpl Phoenix.HTML.Safe, for: Surface.Component.DataContent do
  def to_iodata(data) do
    data
  end
end

defimpl Phoenix.HTML.Safe, for: Surface.Component.Lazy do
  def to_iodata(data) do
    data
  end
end
