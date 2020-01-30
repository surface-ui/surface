defmodule Surface.Translator.ComponentTranslator do
  @moduledoc false

  alias Surface.Translator
  alias Surface.Properties
  import Surface.Translator.ComponentTranslatorHelper

  @behaviour Translator

  @impl true
  def translate(node, caller) do
    {mod_str, attributes, children, meta} = node
    %{module: mod, directives: directives, space: space} = meta

    {children_props, groups_meta, children_contents} =
      translate_children(mod, attributes, directives, children, caller)

    children_props_str = ["%{", Enum.join(children_props, ", "), "}"]
    has_children? = children != []

    open = [
      add_require(mod_str),
      ["<% props = ", Properties.translate_attributes(attributes, mod, mod_str, space, caller), " %>"],
      "<% props = Map.put(props, :__surface__, %{groups: ", groups_meta, "}) %>",
      add_begin_context(mod, mod_str),
      ["<% children_props = ", children_props_str, " %>"],
      add_render_call("live_component", ["@socket", mod_str, "Keyword.new(Map.merge(props, children_props))"], has_children?)
    ]

    close = [
      maybe_add_fallback_content(has_children?),
      maybe_add("<% end %>", has_children?),
      add_end_context(mod, mod_str)
    ]

    {open, Translator.translate(children_contents, caller), close}
  end
end
