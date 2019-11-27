defmodule Surface.Translator.LiveComponentTranslator do
  alias Surface.Translator
  alias Surface.Properties
  import Surface.Translator.ComponentTranslatorUtils

  def translate(node, caller) do
    {mod_str, attributes, children, %{module: mod, translated_props: translated_props}} = node
    {data_children, children} = split_data_children(children)
    has_children? = children != []

    {children_groups_contents, children_groups_attributes} =
      translate_children_groups(mod, attributes, data_children, caller)

    # TODO: Add maybe_generate_id() to create an id automatically if there's a `handle_event`.
    # Also, it's probably better to create a directive :id instead of a property
    children_groups_translated_props =
      Properties.translate_attributes(children_groups_attributes , mod, mod_str, caller)
    all_translated_props = translated_props ++ children_groups_translated_props
    all_props = "Keyword.new(#{Properties.wrap(all_translated_props, mod_str)})"

    open = [
      Translator.translate(children_groups_contents, caller),
      add_require(mod_str),
      add_render_call("live_component", ["@socket", mod_str, all_props], has_children?)
    ]
    close = maybe_add("<% end %>", has_children?)

    {open, Translator.translate(children, caller), close}
  end
end

