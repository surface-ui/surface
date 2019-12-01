defmodule Surface.Translator.LiveViewTranslator do
  alias Surface.Properties
  alias Surface.Translator
  import Surface.Translator.ComponentTranslatorHelper

  @behaviour Translator

  def translate(node, caller) do
    {mod_str, attributes, _children, %{module: mod, line: mod_line}} = node
    translated_session_props = Properties.translate_attributes(attributes, mod, mod_str, mod_line, caller)

    # TODO: Replace this. Create a directive :id?
    live_view_id = :erlang.unique_integer([:positive, :monotonic]) |> to_string()
    session = ["session: %{props: ", translated_session_props, "}, id: \"live_view_", live_view_id, "\""]

    open = [
      add_require(mod_str),
      add_render_call("live_render", ["@socket", mod_str, session])
    ]

    {open, [], []}
  end
end

