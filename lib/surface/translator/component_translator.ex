defmodule Surface.Translator.ComponentTranslator do
  alias Surface.Translator
  alias Surface.Properties
  import Surface.Translator.ComponentTranslatorUtils

  def translate(node, caller) do
    {mod_str, attributes, children, %{module: mod, directives: directives, translated_props: translated_props}} = node
    {data_children, children} = split_data_children(children)

    {children_contents, children_attributes} = translate_children(directives, children, caller)
    {children_groups_contents, children_groups_attributes} =
      translate_children_groups(mod, attributes, data_children, caller)
    all_children_attributes = children_attributes ++ children_groups_attributes

    all_children_translated_props = Properties.translate_attributes(all_children_attributes, mod, mod_str, caller)
    all_translated_props = translated_props ++ all_children_translated_props
    all_props = Properties.wrap(all_translated_props, mod_str)

    open = [
      Translator.translate(children_groups_contents, caller),
      Translator.translate(children_contents, caller),
      add_require(mod_str),
      add_render_call("component", [mod_str, all_props], false)
    ]

    {open, [], []}
  end
end

