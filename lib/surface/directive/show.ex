defmodule Surface.Directive.Show do
  use Surface.Directive

  def extract({":show", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
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
      add_value_to_attribute(node, :style, %AST.Text{value: "display: none;"})
    end
  end

  def process(%AST.Directive{value: %AST.AttributeExpr{} = expr}, node) do
    add_value_to_attribute(node, :style, expr)
  end

  defp add_value_to_attribute(%{attributes: attributes} = node, name, new_value) do
    {%{value: values} = style, non_style} = extract_attribute(attributes || [], name)
    updated_style_attribute = %{style | value: [new_value | values]}
    attributes = [updated_style_attribute | non_style]
    %{node | attributes: attributes}
  end

  defp extract_attribute(attributes, attr_name) do
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
           type: :string,
           value: []
         }, non_style}
    end
  end

  defp directive_value(value, meta) do
    expr = Helpers.attribute_expr_to_quoted!(value, :show, :boolean, meta)

    expr =
      quote generated: true do
        if !unquote(expr) do
          "display: none;"
        end
      end

    %AST.AttributeExpr{
      original: value,
      value: expr,
      meta: meta
    }
  end
end
