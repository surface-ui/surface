defmodule Surface.Directive.SlotProps do
  use Surface.Directive

  def extract({":props", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :props,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  defp directive_value(value, meta) do
    expr = Helpers.attribute_expr_to_quoted!(value, :props, :bindings, meta)

    if !Keyword.keyword?(expr) do
      message = """
      invalid value for directive :props. Expected a keyword list of bindings, \
      got: #{String.trim(value)}.\
      """

      IOHelper.compile_error(message, meta.file, meta.line)
    end

    %AST.AttributeExpr{
      value: expr,
      original: value,
      meta: meta
    }
  end
end
