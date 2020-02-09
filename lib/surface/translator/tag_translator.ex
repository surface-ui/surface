defmodule Surface.Translator.TagTranslator do
  @moduledoc false

  alias Surface.Translator

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

  @phx_events ["phx-click", "phx-blur",  "phx-focus",  "phx-change",  "phx-submit",  "phx-keydown", "phx-keyup"]

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

  defp translate_attribute_assignment(":on-" <> event, value, [space1, space2, space3])
    when event in @phx_events do
    [space1, "<%= on_phx_event(\"", event, "\",", space2, "[", expr_iodata(value), "], assigns[:__surface_cid__]) %>", space3]
  end

  defp translate_attribute_assignment("phx-" <> _ = phx_event, value, [space1, space2, space3])
    when phx_event in @phx_events do
    [space1, phx_event, space2, "=", space3, "<%= phx_event(\"#{phx_event}\", ", expr_iodata(value), ") %>"]
  end

  defp translate_attribute_assignment(key, {:attribute_expr, [expr]}, [space1, space2, space3])
      when key in @boolean_attributes do
    [space1, "<%= boolean_attr(\"", key, "\",", space2, expr, ") %>", space3]
  end

  defp translate_attribute_assignment("class" = key, value, [space1, space2, space3]) do
    value = Surface.Translator.ComponentTranslatorHelper.translate_value(:css_class, key, value, nil, nil)
    [space1, key, space2, "=", space3, wrap_safe_value(value)]
  end

  defp translate_attribute_assignment("surface-cid", value, [space1, space2, space3]) do
    [space1, "surface-cid", space2, "=", space3, wrap_safe_value(value)]
  end

  defp translate_attribute_assignment(key, value, [space1, space2, space3]) do
    [space1, key, space2, "=", space3, wrap_unsafe_value(key, value)]
  end

  defp expr_iodata({:attribute_expr, expr}) do
    expr
  end

  defp expr_iodata(value) do
    [~S("), value, ~S(")]
  end

  defp wrap_safe_value(value) do
    case value do
      {:attribute_expr, value} ->
        expr = value |> IO.iodata_to_binary() |> String.trim()
        [~S("), "<%= ", expr, " %>", ~S(")]
      _ ->
        [~S("), value, ~S(")]
    end
  end

  defp wrap_unsafe_value(key, value) do
    case value do
      {:attribute_expr, value} ->
        expr = value |> IO.iodata_to_binary() |> String.trim()
        [~S("), "<%= attr_value(\"", key, "\", (", expr, ")) %>", ~S(")]
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
