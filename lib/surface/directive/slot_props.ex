defmodule Surface.Directive.SlotArgs do
  use Surface.Directive

  def extract({":args", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :args,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(directive, %AST.Slot{} = slot) do
    %AST.Directive{value: %AST.AttributeExpr{value: value}, meta: meta} = directive

    if Module.get_attribute(meta.caller.module, :component_type) do
      validate_keys!(slot, value, meta)
    end

    %{slot | args: value}
  end

  defp directive_value(value, meta) do
    AST.AttributeExpr.new(
      Surface.TypeHandler.expr_to_quoted!(value, ":args", :explict_keyword, meta),
      value,
      meta
    )
  end

  defp validate_keys!(slot, value, meta) do
    module = slot.meta.caller.module
    slot_definition = Surface.API.get_slots(module) |> Enum.find(&(&1.name == slot.name))
    defined_keys = (slot_definition[:opts][:args] || []) |> Enum.map(& &1.name)
    undefined_keys = Keyword.keys(value) -- defined_keys

    if undefined_keys != [] do
      undefined_text = Helpers.list_to_string("argument", "arguments", undefined_keys)
      defined_text = Helpers.list_to_string("\n\nDefined argument:", "\n\nDefined arguments:", defined_keys)

      message = """
      undefined #{undefined_text} for slot `#{slot.name}`.#{defined_text}

      Hint: You can define a new slot argument using the `args` option: \
      `slot default, args: [..., :some_arg]`
      """

      IOHelper.compile_error(message, meta.file, meta.line)
    end
  end
end
