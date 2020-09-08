defmodule Surface.Directive.TagAttrs do
  use Surface.Directive,
    extract: [
      name: ":attrs",
      type: :map
    ]

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
end
