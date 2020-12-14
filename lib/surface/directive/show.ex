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
      value: %AST.Literal{value: value},
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{value: %AST.Literal{value: value}}, node) do
    add_value_to_attribute(node, :style, %AST.AttributeExpr{
      value:
        quote generated: true do
          unquote(value)
        end,
      original: to_string(value),
      meta: true
    })
  end

  def process(%AST.Directive{value: %AST.AttributeExpr{} = show}, node) do
    add_value_to_attribute(node, :style, show)
  end

  defp add_value_to_attribute(
         %{attributes: attributes, meta: meta} = node,
         name,
         %AST.AttributeExpr{value: value, meta: show_meta} = show
       ) do
    {%{value: style_value, meta: style_meta} = style, non_style} =
      extract_or_create_attribute(attributes || [], name, meta)

    updated_style_value = style_value_to_expr(style_value, style_meta)

    updated_style_attribute = %{style | value: updated_style_value}

    attributes = [
      updated_style_attribute,
      %Surface.AST.Attribute{
        type: :boolean,
        type_opts: [],
        name: :hidden,
        value: %AST.AttributeExpr{
          show
          | value:
              quote generated: true do
                not unquote(value)
              end
        },
        meta: show_meta
      }
      | non_style
    ]

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
           value: %AST.Literal{value: ""},
           meta: meta
         }, non_style}
    end
  end

  defp directive_value(value, meta) do
    expr = Surface.TypeHandler.expr_to_quoted!(value, ":show", :boolean, meta)

    %AST.AttributeExpr{
      original: value,
      value: expr,
      meta: meta
    }
  end

  defp style_value_to_expr(%AST.Literal{value: value}, attr_meta) do
    %AST.AttributeExpr{
      original: value,
      value:
        Surface.TypeHandler.expr_to_quoted!(Macro.to_string(value), ":style", :style, attr_meta),
      meta: attr_meta
    }
  end

  defp style_value_to_expr(attr_value, _attr_meta) do
    attr_value
  end
end
