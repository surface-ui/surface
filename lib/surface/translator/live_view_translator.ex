defmodule Surface.Translator.LiveViewTranslator do
  alias Surface.Properties
  import Surface.Translator.ComponentTranslatorUtils

  def translate(node, _caller) do
    {mod_str, _attributes, _children, %{translated_props: translated_props}} = node
    translated_session_props = Properties.wrap(translated_props, mod_str)

    # TODO: Replace this. Create a directive :id?
    live_view_id = :erlang.unique_integer([:positive, :monotonic]) |> to_string()
    session = ["session: %{props: ", translated_session_props, "}, id: \"live_view_", live_view_id, "\""]

    open = [
      add_require(mod_str),
      add_render_call("live_render", ["@socket", mod_str, session], false)
    ]

    {open, [], []}
  end
end

