defmodule Surface.Directive.Show do
  use Surface.Directive

  def extract({":show", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :show,
      value: directive_value(value, expr_meta),
      meta: attr_meta
    }
  end

  def extract({":show", value, attr_meta}, meta) do
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :show,
      value: %AST.Text{value: value},
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{value: %AST.Text{value: value}}, node) do
    if value do
      node
    else
      add_value_to_attribute(node, :style, value)
    end
  end

  def process(%AST.Directive{value: %AST.AttributeExpr{value: value}}, node) do
    add_value_to_attribute(node, :style, value)
  end

  def maybe_update_display(style, show) do
    if show do
      Keyword.delete(style, :display)
    else
      Keyword.put(style, :display, "none")
    end
  end

  defp add_value_to_attribute(%{attributes: attributes, meta: meta} = node, name, show_value) do
    {%{value: style_value, meta: style_meta} = style, non_style} =
      extract_or_create_attribute(attributes || [], name, meta)

    updated_style_value =
      style_value
      |> style_value_to_expr(style_meta)
      |> wrap_style_value(show_value)

    updated_style_attribute = %{style | value: updated_style_value}

    attributes = [updated_style_attribute | non_style]
    %{node | attributes: attributes}
  end

  defp extract_or_create_attribute(attributes, attr_name, meta) do
    attributes
    |> Enum.split_with(fn
      %{name: name} when name == attr_name -> true
      _ -> false
    end)
    |> case do
      {[style], non_style} ->
        {style, non_style}

      {_, non_style} ->
        {%AST.Attribute{
           name: :style,
           type: :style,
           value: %AST.Text{value: ""},
           meta: meta
         }, non_style}
    end
  end

  defp directive_value(value, meta) do
    expr = Helpers.attribute_expr_to_quoted!(value, ":show", :boolean, meta)

    %AST.AttributeExpr{
      original: value,
      value: expr,
      meta: meta
    }
  end

  defp style_value_to_expr(%AST.Text{value: value}, attr_meta) do
    %AST.AttributeExpr{
      original: value,
      value:
        Helpers.attribute_expr_to_quoted!(Macro.to_string(value), ":style", :style, attr_meta),
      meta: attr_meta
    }
  end

  defp style_value_to_expr(attr_value, _attr_meta) do
    attr_value
  end

  defp wrap_style_value(%AST.AttributeExpr{value: value} = expr, show_value) do
    updated_value =
      quote generated: true do
        unquote(__MODULE__).maybe_update_display(unquote(value), unquote(show_value))
      end

    %AST.AttributeExpr{expr | value: updated_value}
  end
end
