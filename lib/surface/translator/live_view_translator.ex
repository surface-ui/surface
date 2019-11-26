defmodule Surface.Translator.LiveViewTranslator do
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

    has_children? = children != []

    translated_session_props = Properties.translate_attributes(attributes, mod, mod_str, caller)

    # TODO: Replace this. Create a directive :id?
    live_view_id = :erlang.unique_integer([:positive, :monotonic]) |> to_string()

    session = ["session: %{props: ", translated_session_props, "}, id: \"live_view_", live_view_id, "\""]

    [
      Directive.maybe_add_directives_begin(directives),
      add_require(mod_str),
      add_render_call("live_render", ["@socket", mod_str, session], has_children?),
      maybe_add(Translator.translate(children, caller), has_children?),
      maybe_add("<% end %>", has_children?),
      Directive.maybe_add_directives_end(directives)
    ]
  end
end

