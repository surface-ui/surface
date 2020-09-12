defmodule Surface.Directive.For do
  use Surface.Directive,
    extract: [
      name: ":for",
      type: :generator,
      modifiers: ["index", "with_index"]
    ]

  def process(%AST.Directive{value: %AST.AttributeExpr{} = expr, meta: meta}, node),
    do: %AST.For{generator: expr, children: [node], meta: meta}

  def handle_modifier([{:<-, clause_meta, [var, list]}], "with_index", _meta) do
    updated_list =
      quote generated: true do
        Enum.with_index(unquote(list))
      end

    [{:<-, clause_meta, [var, updated_list]}]
  end

  def handle_modifier([{:<-, clause_meta, [var, list]}], "index", _meta) do
    updated_list =
      quote generated: true do
        Enum.scan(unquote(list), -1, fn _, a -> a + 1 end)
      end

    [{:<-, clause_meta, [var, updated_list]}]
  end

  def handle_modifier([{_, clause_meta, _} = list], "index", _meta) do
    var =
      quote generated: true do
        var!(index)
      end

    updated_list =
      quote generated: true do
        Enum.scan(unquote(list), -1, fn _, a -> a + 1 end)
      end

    [{:<-, clause_meta, [var, updated_list]}]
  end

  def handle_modifier(clauses, modifier, meta) when length(clauses) > 1 do
    message = "cannot apply modifier \"#{modifier}\" on generators with multiple clauses"
    IOHelper.compile_error(message, meta.file, meta.line)
  end
end
