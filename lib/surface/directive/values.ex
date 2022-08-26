defmodule Surface.Directive.Values do
  use Surface.Directive

  def extract({":values", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    expr_meta = Helpers.to_meta(expr_meta, meta)
    attr_meta = Helpers.to_meta(attr_meta, meta)

    %AST.Directive{
      module: __MODULE__,
      name: :values,
      value: directive_value(value, expr_meta),
      meta: attr_meta
    }
  end

  def extract(_, _), do: []

  def process(
        %AST.Directive{
          value: %AST.AttributeExpr{value: value} = expr,
          meta: meta
        },
        %type{attributes: attributes} = node
      )
      when type in [AST.Tag, AST.VoidTag] do
    attr_names = for %AST.Attribute{name: name} <- attributes, do: name

    new_expr =
      quote do
        for {name, value} <- unquote(value) || [],
            attr_name = :"phx-value-#{name}",
            not Enum.member?(unquote(Macro.escape(attr_names)), attr_name) do
          unquote(__MODULE__).validate_value!(name, value)
          {attr_name, {Surface.TypeHandler.attribute_type_and_opts(attr_name), to_string(value)}}
        end
      end

    %{
      node
      | attributes: [
          %AST.DynamicAttribute{
            name: :values,
            meta: meta,
            expr: %AST.AttributeExpr{expr | value: new_expr}
          }
          | attributes
        ]
    }
  end

  defp directive_value(value, meta) do
    AST.AttributeExpr.new(
      Surface.TypeHandler.expr_to_quoted!(value, ":values", :map, meta),
      value,
      meta
    )
  end

  def validate_value!(name, value) do
    unless String.Chars.impl_for(value) do
      message = """
      invalid value for key "#{inspect(name)}" in attribute ":values".

      Expected a type that implements the String.Chars protocol (e.g. string, boolean, integer, atom, ...), \
      got: #{inspect(value)}\
      """

      IOHelper.runtime_error(message)
    end
  end
end
