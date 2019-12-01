defmodule Surface.Translator.LiveViewTranslator do
  alias Surface.Properties
  alias Surface.Translator
  import Surface.Translator.ComponentTranslatorHelper

  @behaviour Translator

  def translate(node, caller) do
    {mod_str, attributes, _children, %{module: mod, line: mod_line}} = node

    # TODO: Validation: only accept `id` and `session` properties
    props = Properties.translate_attributes(attributes, mod, mod_str, mod_line, caller, put_default_props: false)

    open = [
      ["<% props = ", props , " %>"],
      add_require(mod_str),
      add_render_call("live_render", ["@socket", mod_str, "Keyword.new(props)"])
    ]

    {open, [], []}
  end
end

