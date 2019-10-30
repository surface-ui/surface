defmodule Surface.DefaultComponentTranslator do
  alias Surface.Properties
  alias Surface.NodeTranslator

  import Surface.Translator

  def translate(mod_str, attributes, [], mod, caller, opts) do
    renderer = Keyword.fetch!(opts, :renderer)
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    args = maybe_add_socket([mod_str, rendered_props], opts)

    ["<%= ", inspect(renderer), ".render(",  Enum.join(args, ", "), ") %>"]
  end

  def translate(mod_str, attributes, children, mod, caller, opts) do
    renderer = Keyword.fetch!(opts, :renderer)
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    args = maybe_add_socket([mod_str, rendered_props], opts)

    bindings = lazy_values(mod, attributes)
    [
      maybe_add_begin_context(mod, mod_str, rendered_props),
      "<%= ", inspect(renderer), ".render(",  Enum.join(args, ", "), ") do %>",
      maybe_add_begin_lazy_content(bindings),
      NodeTranslator.translate(children, caller),
      maybe_add_end_lazy_content(bindings),
      "<% end %>",
      maybe_add_end_context(mod, mod_str, rendered_props)
    ]
  end

  defp maybe_add_socket(args, opts) do
    if Keyword.fetch!(opts, :pass_socket) do
      ["@socket" | args]
    else
      args
    end
  end

  defp lazy_values(mod, attributes) do
    for {key, value, _line} <- attributes, key in mod.__lazy_vars__() do
      value
    end
  end
end
