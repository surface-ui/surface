defmodule Surface.Directive.ComponentProps do
  use Surface.Directive

  def extract({":props", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :props,
      value: directive_value(value, expr_meta),
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{value: %AST.AttributeExpr{value: value} = expr, meta: meta},
        %AST.Component{module: module, props: props} = node
      ) do
    static_prop_names =
      props
      |> Enum.filter(fn
        %AST.Attribute{} -> true
        _ -> false
      end)
      |> Enum.map(fn %AST.Attribute{name: name} -> name end)

    new_expr =
      quote generated: true do
        for {name, value} <- unquote(value) || [],
            not Enum.member?(unquote(Macro.escape(static_prop_names)), name) do
          {name, Surface.TypeHandler.runtime_prop_value!(unquote(module), name, value, unquote(meta.node_alias))}
        end
      end

    %{
      node
      | dynamic_props: %AST.DynamicAttribute{
          name: :props,
          meta: meta,
          expr: %{expr | value: new_expr}
        }
    }
  end

  defp directive_value(value, meta) do
    %AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(value, ":props", :map, meta),
      meta: meta
    }
  end
end
