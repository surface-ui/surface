defmodule Surface.Directive.For do
  use Surface.Directive

  def extract({":for", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :for,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta), attr_meta),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta}, node),
    do: %AST.For{generator: expr, children: [node], meta: meta}

  defp directive_value(value, meta, attr_meta) do
    quoted_value =
      value
      |> Surface.TypeHandler.expr_to_quoted!(":for", :generator, meta)
      |> handle_modifiers(attr_meta.modifiers, %{line: attr_meta.line, file: meta.file})

    %AST.AttributeExpr{
      original: value,
      value: quoted_value,
      meta: meta
    }
  end

  defp handle_modifiers([{:<-, clause_meta, [var, list]}], ["with_index" | modifiers], meta) do
    udpated_list =
      quote generated: true do
        Enum.with_index(unquote(list))
      end

    handle_modifiers([{:<-, clause_meta, [var, udpated_list]}], modifiers, meta)
  end

  defp handle_modifiers([{:<-, clause_meta, [var, list]}], ["index" | modifiers], meta) do
    udpated_list =
      quote generated: true do
        Enum.scan(unquote(list), -1, fn _, a -> a + 1 end)
      end

    handle_modifiers([{:<-, clause_meta, [var, udpated_list]}], modifiers, meta)
  end

  defp handle_modifiers([{_, clause_meta, _} = list], ["index" | modifiers], meta) do
    var =
      quote generated: true do
        var!(index)
      end

    udpated_list =
      quote generated: true do
        Enum.scan(unquote(list), -1, fn _, a -> a + 1 end)
      end

    handle_modifiers([{:<-, clause_meta, [var, udpated_list]}], modifiers, meta)
  end

  defp handle_modifiers(clauses, [modifier | _modifiers], meta) when length(clauses) > 1 do
    message = "cannot apply modifier \"#{modifier}\" on generators with multiple clauses"
    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp handle_modifiers(_clauses, [modifier | _modifiers], meta) do
    message = "unknown modifier \"#{modifier}\" for directive :for"
    IOHelper.compile_error(message, meta.file, meta.line)
  end

  defp handle_modifiers(clauses, [], _meta) do
    clauses
  end
end
