defmodule Surface.Translator.LiveViewTranslator do
  @moduledoc false

  alias Surface.Translator
  import Surface.Translator.ComponentTranslatorHelper

  @behaviour Translator

  @impl true
  def translate(node, caller) do
    {mod_str, attributes, _children, %{module: mod, space: space}} = node

    # TODO: Validation: only accept `id` and `session` properties
    props = translate_attributes(attributes, mod, mod_str, space, caller, put_default_props: false)

    open = [
      ["<% props = ", props , " %>"],
      add_require(mod_str),
      add_render_call("live_render", ["@socket", mod_str, "Keyword.new(props)"])
    ]

    {open, [], []}
  end
end

