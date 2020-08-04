defmodule Surface.Directive.Let do
  use Surface.Directive

  def extract({":let", {:attribute_expr, [value], expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :let,
      value: directive_value(value, Map.merge(meta, expr_meta)),
      meta: Map.merge(meta, attr_meta)
    }
  end

  def extract(_, _), do: []

  defp directive_value(value, meta) do
    # using a list here because it doesn't wrap the result in a function call
    # to Surface.<type>_value(...)
    expr = Helpers.attribute_expr_to_quoted!(value, :let, :list, meta)

    if !Keyword.keyword?(expr) do
      invalid_let_binding(value, meta)
    end

    for binding <- expr do
      if not match?({prop, {binding_name, _, nil}} when is_atom(binding_name), binding) do
        invalid_let_binding(value, meta)
      end
    end

    %AST.AttributeExpr{
      value: expr,
      original: value,
      meta: meta
    }
  end

  defp invalid_let_binding(value, meta) do
    message = """
    invalid value for directive :let. Expected a keyword list of bindings, \
    got: #{String.trim(value)}.\
    """

    IOHelper.compile_error(message, meta.file, meta.line)
  end
end
