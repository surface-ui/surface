defmodule Surface.Directive.TagAttrs do
  use Surface.Directive

  def extract({":attrs", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :attrs,
      value: directive_value(value, expr_meta),
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{value: %AST.AttributeExpr{value: value} = expr, meta: meta},
        %type{attributes: attributes} = node
      )
      when type in [AST.Tag, AST.VoidTag] do
    attr_names =
      attributes
      |> Enum.filter(fn
        %AST.Attribute{} -> true
        _ -> false
      end)
      |> Enum.map(fn %AST.Attribute{name: name} -> name end)

    new_expr =
      quote generated: true do
        for {name, value} <- unquote(value) || [],
            not Enum.member?(unquote(Macro.escape(attr_names)), name) do
          {name, {Surface.TypeHandler.attribute_type_and_opts(name), value}}
        end
      end

    %{
      node
      | attributes: [
          %AST.DynamicAttribute{name: :attrs, meta: meta, expr: %{expr | value: new_expr}}
          | attributes
        ]
    }
  end

  defp directive_value(value, meta) do
    %AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(value, ":attrs", :map, meta),
      meta: meta
    }
  end
end
