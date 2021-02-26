defmodule Surface.Directive.Hook do
  use Surface.Directive

  def extract({":hook", value, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :hook,
      value: directive_value(value, attr_meta, meta),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{value: %AST.AttributeExpr{value: value} = expr, meta: meta},
        %type{attributes: attributes} = node
      )
      when type in [AST.Tag, AST.VoidTag] do
    new_expr =
      quote generated: true do
        [{"phx-hook", {:string, unquote(__MODULE__).hook_name(unquote(value))}}]
      end

    %{
      node
      | attributes: [
          %AST.DynamicAttribute{name: :hook, meta: meta, expr: %{expr | value: new_expr}}
          | attributes
        ]
    }
  end

  @doc false
  def hook_name(value) when value in [nil, false] do
    value
  end

  def hook_name({hook, mod}) do
    "#{inspect(mod)}\##{hook}"
  end

  defp directive_value({:attribute_expr, value, expr_meta}, _attr_meta, meta) do
    new_meta = Helpers.to_meta(expr_meta, meta)

    %AST.AttributeExpr{
      original: value,
      value: Surface.TypeHandler.expr_to_quoted!(value, ":hook", :hook, new_meta),
      meta: meta
    }
  end

  defp directive_value(value, attr_meta, meta) do
    new_meta = Helpers.to_meta(attr_meta, meta)
    Surface.TypeHandler.literal_to_ast_node!(:hook, ":hook", value, new_meta)
  end
end
