defmodule Surface.Translator.LiveComponentTranslator do
  @moduledoc false

  alias Surface.Translator
  alias Surface.Translator.TagTranslator
  alias Surface.IOHelper
  import Surface.Translator.ComponentTranslatorHelper

  @behaviour Translator

  @impl true
  def prepare(nodes, caller) do
    validate_root_node(nodes, caller)
  end

  @impl true
  def translate(node, caller) do
    {mod_str, attributes, children, meta} = node
    %{module: mod, directives: directives, space: space} = meta

    {children_props, slots_meta, children_contents} =
      translate_children(mod_str, mod, attributes, directives, children, caller)

    children_props_str = ["%{", Enum.join(children_props, ", "), "}"]
    has_children? = children != []

    open = [
      add_require(mod_str),
      ["<% props = ", translate_attributes(attributes, mod, mod_str, space, caller), " %>"],
      "<% props = Map.put(props, :__surface__, %{slots: ",
      slots_meta,
      "}) %>",
      add_begin_context(mod, mod_str),
      ["<% children_props = ", children_props_str, " %>"],
      add_render_call(
        "live_component",
        ["@socket", mod_str, "Keyword.new(Map.merge(props, children_props))"],
        has_children?
      )
    ]

    close = [
      maybe_add("<% end %>", has_children?),
      add_end_context(mod, mod_str)
    ]

    {open, Translator.translate(children_contents, caller), close}
  end

  defp validate_root_node(children, caller) do
    {nodes, n_tags, _n_binary} =
      Enum.reduce(children, {[], 0, 0}, fn child, {nodes, n_tags, n_non_tags} ->
        cond do
          blank?(child) ->
            {[child | nodes], n_tags, n_non_tags}

          is_binary(child) ->
            {[child | nodes], n_tags, n_non_tags + 1}

          match?({:interpolation, _, _}, child) ->
            {[child | nodes], n_tags, n_non_tags + 1}

          n_tags + n_non_tags == 0 && match?({_, _, _, %{translator: TagTranslator}}, child) ->
            {[child | nodes], n_tags + 1, n_non_tags}

          true ->
            {_, _, _, %{line: line}} = child
            message = "stateful live components must have a single HTML root element"
            IOHelper.warn(message, caller, &(&1 + line))
            {[child | nodes], n_tags + 1, n_non_tags}
        end
      end)

    if n_tags == 0 do
      message = "stateful live components must have a HTML root element"
      IOHelper.warn(message, caller, &(&1 + 1))
    end

    Enum.reverse(nodes)
  end
end
