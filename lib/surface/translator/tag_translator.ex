defmodule Surface.Translator.TagTranslator do
  @moduledoc false

  alias Surface.Translator
  alias Surface.Properties

  @behaviour Translator

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
      [space1, space2, space3] ->
        [space1, key, space2, "=", space3, wrap_value(value)]

      [space1, space2] ->
        [space1, key, space2]
    end
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
