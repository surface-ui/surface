defmodule Surface.Translator.TagTranslator do
  @moduledoc false

  alias Surface.Translator

  @behaviour Translator

  @void_elements [
    "area",
    "base",
    "br",
    "col",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "command",
    "keygen",
    "source"
  ]

  @boolean_attributes [
    "allowfullscreen",
    "allowpaymentrequest",
    "async",
    "autofocus",
    "autoplay",
    "checked",
    "controls",
    "default",
    "defer",
    "disabled",
    "formnovalidate",
    "hidden",
    "ismap",
    "itemscope",
    "loop",
    "multiple",
    "muted",
    "nomodule",
    "novalidate",
    "open",
    "readonly",
    "required",
    "reversed",
    "selected",
    "typemustmatch"
  ]

  @phx_events [
    "phx-click",
    "phx-capture-click",
    "phx-blur",
    "phx-focus",
    "phx-change",
    "phx-submit",
    "phx-keydown",
    "phx-keyup",
    "phx-window-keydown",
    "phx-window-keyup"
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
    for {key, value, meta} <- attributes do
      value = replace_attribute_expr(value)
      translate_attribute(key, value, meta)
    end
  end

  defp translate_attribute(key, value, %{spaces: spaces} = meta) do
    case spaces do
      [_space1, _space2, _space3] ->
        translate_attribute_assignment(key, value, meta)

      [space1, space2] ->
        [space1, key, space2]
    end
  end

  defp translate_attribute_assignment(":on-" <> event, value, %{spaces: spaces})
       when event in @phx_events do
    [space1, space2, space3] = spaces

    [
      space1,
      "<%= on_phx_event(\"",
      event,
      "\",",
      space2,
      "[",
      value_to_code(value),
      "], assigns[:myself]) %>",
      space3
    ]
  end

  defp translate_attribute_assignment("phx-" <> _ = phx_event, value, %{spaces: spaces})
       when phx_event in @phx_events do
    [space1, space2, space3] = spaces

    [
      space1,
      phx_event,
      space2,
      "=",
      space3,
      "<%= phx_event(\"#{phx_event}\", ",
      value_to_code(value),
      ") %>"
    ]
  end

  defp translate_attribute_assignment(key, {:attribute_expr, [expr], _}, %{spaces: spaces})
       when key in @boolean_attributes do
    [space1, space2, space3] = spaces
    [space1, "<%= boolean_attr(\"", key, "\",", space2, expr, ") %>", space3]
  end

  defp translate_attribute_assignment("class" = key, value, %{spaces: spaces}) do
    [space1, space2, space3] = spaces

    value =
      Surface.Translator.ComponentTranslatorHelper.translate_value(
        :css_class,
        key,
        value,
        nil,
        nil
      )

    [space1, key, space2, "=", space3, wrap_safe_value(value)]
  end

  defp translate_attribute_assignment("style" = key, value, meta) do
    %{spaces: [space1, space2, space3]} = meta
    show_expr = Map.get(meta, :directive_show_expr, "true")

    [
      space1,
      key,
      space2,
      "=",
      space3,
      "<%= style(",
      value_to_code(value),
      ", ",
      show_expr,
      ") %>"
    ]
  end

  defp translate_attribute_assignment(key, value, %{spaces: spaces}) do
    [space1, space2, space3] = spaces
    [space1, "<%= attr(\"", key, "\",", space2, value_to_code(value), ") %>", space3]
  end

  defp value_to_code({:attribute_expr, expr, _}) do
    expr |> IO.iodata_to_binary() |> String.trim()
  end

  defp value_to_code(value) do
    [~S("), value, ~S(")]
  end

  defp wrap_safe_value(value) do
    [~S("), "<%= ", value_to_code(value), " %>", ~S(")]
  end

  defp wrap_unsafe_value(key, value) do
    [~S("), "<%= attr_value(\"", key, "\", ", value_to_code(value), ") %>", ~S(")]
  end

  defp replace_attribute_expr(value) when is_list(value) do
    for item <- value do
      case item do
        {:attribute_expr, [expr], _} ->
          ["\#{", expr, "}"]

        _ ->
          item
      end
    end
  end

  defp replace_attribute_expr(value) do
    value
  end
end
