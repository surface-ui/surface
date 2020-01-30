defmodule Surface.Translator.TagTranslator do
  @moduledoc false

  alias Surface.Translator
  alias Surface.Properties

  @behaviour Translator

  @void_elements [
    "area", "base", "br", "col", "hr", "img", "input", "link",
    "meta", "param", "command", "keygen", "source"
  ]

  @boolean_attributes [
    "allowfullscreen", "allowpaymentrequest", "async", "autofocus", "autoplay", "checked",
    "controls", "default", "defer", "disabled", "formnovalidate", "hidden", "ismap",
    "itemscope", "loop", "multiple", "muted", "nomodule", "novalidate", "open", "readonly",
    "required", "reversed", "selected", "typemustmatch"
  ]

  @impl true
  def translate({tag_name, attributes, _, %{space: space}}, _) when tag_name in @void_elements do
    {["<", tag_name, translate_attributes(attributes), space, ">"], [], []}
  end

  @impl true
  def translate(node, caller) do
    {tag_name, attributes, children, %{space: space}} = node

    {
      ["<", tag_name, translate_attributes(attributes), space, ">"],
      Translator.translate(children, caller),
      ["</", tag_name, ">"]
    }
  end

  defp translate_attributes(attributes) do
    for {key, value, %{spaces: spaces}} <- attributes do
      value = replace_attribute_expr(value)
      value =
        if key in ["class", :class] do
          Properties.translate_value(:css_class, value, nil, nil)
        else
          value
        end
      translate_attribute(key, value, spaces)
    end
  end

  defp translate_attribute(key, value, spaces) do
    case spaces do
      [_space1, _space2, _space3] ->
        translate_attribute_assignment(key, value, spaces)

      [space1, space2] ->
        [space1, key, space2]
    end
  end

  defp translate_attribute_assignment(":on-" <> event, {:attribute_expr, [expr]}, [space1, space2, space3]) do
    [space1, "<%= on_event(\"", event, "\",", space2, "[", expr, "], assigns[:__surface_cid__]) %>", space3]
  end

  defp translate_attribute_assignment(key, {:attribute_expr, [expr]}, [space1, space2, space3])
      when key in @boolean_attributes do
    [space1, "<%= boolean_attr(\"", key, "\",", space2, expr, ") %>", space3]
  end

  defp translate_attribute_assignment(key, value, [space1, space2, space3]) do
    [space1, key, space2, "=", space3, wrap_value(value)]
  end

  defp wrap_value(value) do
    case value do
      {:attribute_expr, value} ->
        expr = value |> IO.iodata_to_binary() |> String.trim()
        [~S("), "<%= ", expr, " %>", ~S(")]
      _ ->
        [~S("), value, ~S(")]
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
