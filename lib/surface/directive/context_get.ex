defmodule Surface.Directive.ContextGet do
  use Surface.Directive

  def extract({":get", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :get,
      value: directive_value(value, expr_meta),
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{value: value, meta: meta},
        %AST.Component{module: Surface.Components.Context, props: props} = node
      ) do
    get_prop = %AST.Attribute{
      type: :context_get,
      type_opts: [accumulate: true],
      name: :__get__,
      value: value,
      meta: meta
    }

    props = [get_prop | props]

    %{node | props: props}
  end

  def process(
        directive,
        %{meta: meta} = node
      ) do
    process(
      directive,
      # TODO: if we want to keep this, then we should probably abstract some of this away
      %AST.Component{
        type: Surface.Component,
        module: Surface.Components.Context,
        props: [],
        dynamic_props: nil,
        directives: [],
        templates: %{
          default: [
            %AST.Template{
              name: :default,
              children: [node],
              let: %AST.Directive{
                module: Surface.Directive.Let,
                name: :let,
                value: %AST.AttributeExpr{
                  value: [],
                  original: "",
                  meta: meta
                },
                meta: meta
              },
              meta: meta
            }
          ]
        },
        debug: [],
        meta: meta
      }
    )
  end

  defp directive_value(value, meta) do
    expr = Surface.TypeHandler.expr_to_quoted!(value, ":get", :context_get, meta)

    %AST.AttributeExpr{
      value: expr,
      original: value,
      meta: meta
    }
  end
end
