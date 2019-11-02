defmodule Surface.Translator.TagNode do
  import Surface.Translator
  alias Surface.Translator.NodeTranslator

  defstruct [:name, :attributes, :children, :line]

  defimpl NodeTranslator do
    def translate(%{name: tag_name, children: []} = node, caller) do
      %{attributes: attributes, line: line} = node
      ["<", tag_name, render_tag_props(attributes), "/>"]
      |> debug(attributes, line, caller)
    end

    def translate(%{name: tag_name} = node, caller) do
      %{attributes: attributes, children: children, line: line} = node
      {directives, attributes} = pop_directives(attributes)
      [
        maybe_add_directives_begin(directives),
        ["<", tag_name, render_tag_props(attributes), ">"],
        maybe_add_directives_after_begin(directives),
        NodeTranslator.translate(children, caller),
        ["</", tag_name, ">"],
        maybe_add_directives_end(directives)
      ] |> debug(attributes, line, caller)
    end

    def translate(node, _caller) do
      node
    end

    defp render_tag_props(props) do
      for {key, value, _line} <- props do
        value = replace_attribute_expr(value)
        value =
          if key in ["class", :class] do
            Surface.Properties.translate_value(:css_class, value, nil, nil)
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
end
