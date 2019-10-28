defmodule Surface.DataComponentRenderer do
  alias Surface.Properties
  alias Surface.BaseComponent.DataContent
  alias Surface.BaseComponent.LazyContent

  # TODO: Rename to `translate`
  def render_code(mod_str, attributes, [], mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    ["<%= Surface.DataComponentRenderer.render(", mod_str, ", ", rendered_props, ") %>"]
  end

  def render_code(mod_str, attributes, children_iolist, mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    bindings = mod.bindings()
    [
      maybe_add_begin_context(mod, mod_str, rendered_props),
      "<%= Surface.DataComponentRenderer.render(", mod_str, ", ", rendered_props, ") do %>",
      maybe_add_begin_lazy_content(bindings),
      children_iolist,
      maybe_add_end_lazy_content(bindings),
      "<% end %>",
      maybe_add_end_context(mod, mod_str, rendered_props)
    ]
  end

  def render(module, props) do
    do_render(module, props, [])
  end

  def render(module, props, do: block) do
    do_render(module, props, block)
  end

  defp do_render(module, props, content) do
    props =
      props
      |> Map.put(:content, content)
      |> put_default_props(module)

    {:ok, data} = module.init(props)

    assigns =
      case data do
        %{content: {:safe, [%LazyContent{func: func}]}} ->
          Map.put(data, :inner_content, func)
        data ->
            data
      end
    %DataContent{data: assigns, component: module}
  end

  defp maybe_add_begin_context(mod, mod_str, rendered_props) do
    if function_exported?(mod, :begin_context, 1) do
      ["<% context = ", mod_str, ".begin_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end

  defp maybe_add_end_context(mod, mod_str, rendered_props) do
    if function_exported?(mod, :end_context, 1) do
      ["<% context = ", mod_str, ".end_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end

  defp maybe_add_begin_lazy_content([]) do
    ""
  end

  defp maybe_add_begin_lazy_content(bindings) do
    args =
      for binding <- bindings, name = to_string(binding) do
        [name, ": ", name]
      end
    ["<%= lazy fn ", Enum.join(args, ", "), " -> %>"]
  end

  defp maybe_add_end_lazy_content([]) do
    ""
  end

  defp maybe_add_end_lazy_content(_bindings) do
    ["<% end %>"]
  end

  defp put_default_props(props, mod) do
    Enum.reduce(mod.__props(), props, fn %{name: name, default: default}, acc ->
      Map.put_new(acc, name, default)
    end)
  end
end
