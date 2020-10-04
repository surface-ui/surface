defmodule Surface.Directive.SlotProps do
  use Surface.Directive

  def extract({":props", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :props,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(directive, %AST.Slot{} = slot) do
    %AST.Directive{value: %AST.AttributeExpr{value: value}, meta: meta} = directive
    validate_keys!(slot, value, meta)
    %{slot | props: value}
  end

  defp directive_value(value, meta) do
    %AST.AttributeExpr{
      value: Surface.TypeHandler.expr_to_quoted!(value, ":props", :explict_keyword, meta),
      original: value,
      meta: meta
    }
  end

  defp validate_keys!(slot, value, meta) do
    module = slot.meta.caller.module
    slot_definition = Surface.API.get_slots(module) |> Enum.find(&(&1.name == slot.name))
    defined_keys = (slot_definition[:opts][:props] || []) |> Enum.map(& &1.name)
    undefined_keys = Keyword.keys(value) -- defined_keys

    if undefined_keys != [] do
      undefined_text = Helpers.list_to_string("prop", "props", undefined_keys)
      defined_text = Helpers.list_to_string("prop:", "props:", defined_keys)

      message = """
      undefined #{undefined_text} for slot `#{slot.name}`.

      Defined #{defined_text}.

      Hint: You can define a new slot prop using the `props` option: \
      `slot default, props: [..., :some_prop]`\
      """

      IOHelper.compile_error(message, meta.file, meta.line)
    end
  end
end
