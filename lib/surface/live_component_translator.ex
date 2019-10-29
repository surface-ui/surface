defmodule Surface.LiveComponentTranslator do
  alias Surface.Properties
  alias Surface.NodeTranslator

  import Surface.Translator
  require Phoenix.LiveView

  # TODO: Rename to `translate`
  def render_code(mod_str, attributes, [], mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    ["<%= Surface.LiveComponentRenderer.render(@socket, ", mod_str, ", ", rendered_props, ") %>"]
  end

  def render_code(mod_str, attributes, children, mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    bindings = lazy_values(mod, attributes)
    [
      maybe_add_begin_context(mod, mod_str, rendered_props),
      "<%= Surface.LiveComponentRenderer.render(@socket, ", mod_str, ", ", rendered_props, ") do %>",
      maybe_add_begin_lazy_content(bindings),
      NodeTranslator.translate(children, caller),
      maybe_add_end_lazy_content(bindings),
      "<% end %>",
      maybe_add_end_context(mod, mod_str, rendered_props)
    ]
  end

  defp lazy_values(mod, attributes) do
    for {key, value, _line} <- attributes, key in mod.__lazy_vars__() do
      value
    end
  end
end
