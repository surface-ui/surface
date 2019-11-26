defmodule Surface.Translator.TagTranslator do
  alias Surface.Translator
  alias Surface.Translator.Directive
  alias Surface.Properties

  def translate(node, caller) do
    {tag_name, attributes, children, %{line: line}} = node
    {directives, attributes} = Directive.pop_directives(attributes)
    [
      Directive.maybe_add_directives_begin(directives),
      ["<", tag_name, render_tag_props(attributes), ">"],
      Translator.translate(children, caller),
      ["</", tag_name, ">"],
      Directive.maybe_add_directives_end(directives)
    ] |> Surface.Translator.IO.debug(attributes, line, caller)
  end

  defp render_tag_props(props) do
    for {key, value, _line} <- props do
      value = replace_attribute_expr(value)
      value =
        if key in ["class", :class] do
          Properties.translate_value(:css_class, value, nil, nil)
        else
          value
        end
      render_tag_prop_value(key, value)
    end
  end

  defp render_tag_prop_value(key, value) do
    case value do
      {:attribute_expr, value} ->
        expr = value |> IO.iodata_to_binary() |> String.trim()
        [" ", key, "=", ~S("), "<%= ", expr, " %>", ~S(")]
      _ ->
        [" ", key, "=", ~S("), value, ~S(")]
    end
  end

  defp replace_attribute_expr(value) when is_list(value) do
    for item <- value do
      case item do
        {:attribute_expr, [expr]} ->
          ["<%= ", expr, " %>"]
        _ ->
          item
      end
    end
  end

  defp replace_attribute_expr(value) do
    value
  end
end
