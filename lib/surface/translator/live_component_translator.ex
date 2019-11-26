defmodule Surface.Translator.LiveComponentTranslator do
  alias Surface.Translator
  alias Surface.Translator.Directive
  alias Surface.Properties
  import Surface.Translator.ComponentTranslatorUtils

  def translate(node, caller) do
    {mod_str, attributes, children, %{module: mod}} = node
    {data_children, children} = split_data_children(children)
    {directives, attributes} = Directive.pop_directives(attributes)

    # TODO: Find a better approach for this. For now, if there's any
    # DataComponent and the rest of children are blank, we remove them.
    children =
      if data_children != %{} && String.trim(IO.iodata_to_binary(children)) == "" do
        []
      else
        children
      end

    ######

    {children_groups_contents, children_attributes} =
      translate_children_groups(mod, attributes, data_children, caller)

    has_children? = children != []

    # TODO: Add maybe_generate_id() to create an id automatically if there's a `handle_event`.
    # Also, it's probably better to create a directive :id instead of a property
    all_attributes = attributes ++ children_attributes
    translated_props = Properties.translate_attributes(all_attributes , mod, mod_str, caller)
    translated_props = "Keyword.new(#{translated_props})"

    [
      Directive.maybe_add_directives_begin(directives),
      maybe_add_context_begin(mod, mod_str, translated_props),
      Translator.translate(children_groups_contents, caller),
      add_require(mod_str),
      add_render_call("live_component", ["@socket", mod_str, translated_props], has_children?),
      Directive.maybe_add_directives_after_begin(directives),
      "<% _ = assigns %>", # We need this to silence a warning. Probably due to a bug in live_component
      Translator.translate(children, caller),
      maybe_add("<% end %>", has_children?),
      maybe_add_context_end(mod, mod_str, translated_props),
      Directive.maybe_add_directives_end(directives)
    ]
  end
end

