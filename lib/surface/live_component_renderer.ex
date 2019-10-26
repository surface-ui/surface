# TODO: Rename to `Surface.ComponentTranslator`
defmodule Surface.LiveComponentRenderer do
  alias Surface.BaseComponent.DataContent
  alias Surface.Properties
  require Phoenix.LiveView

  # TODO: Rename to `translate`
  def render_code(mod_str, attributes, [], mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    ["<%= Surface.LiveComponentRenderer.render(@socket, ", mod_str, ", ", rendered_props, ") %>"]
  end

  def render_code(mod_str, attributes, children_iolist, mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    [
      maybe_add_begin_context(mod, mod_str, rendered_props),
      "<%= Surface.LiveComponentRenderer.render(@socket, ", mod_str, ", ", rendered_props, ") do %>",
      children_iolist,
      "<% end %>",
      maybe_add_end_context(mod, mod_str, rendered_props)
    ]
  end

  def render(socket, module, props) do
    do_render(socket, module, props, [])
  end

  def render(socket, module, props, do: block) do
    do_render(socket, module, props, block)
  end

  defp do_render(socket, module, props, content) do
    props =
      props
      |> Map.put(:content, content)
      |> put_default_props(module)

    Phoenix.LiveView.live_component(socket, module, Keyword.new(props), content)
    # case module.render(props) do
    #   {:data, data} ->
    #     %DataContent{data: data, component: module}
    #   result ->
    #     result
    # end
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

  defp put_default_props(props, mod) do
    Enum.reduce(mod.__props(), props, fn %{name: name, default: default}, acc ->
      Map.put_new(acc, name, default)
    end)
  end
end
