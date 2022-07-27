defmodule Surface.Directive.SlotArg do
  use Surface.Directive

  def extract({":arg", {:attribute_expr, value, expr_meta}, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :arg,
      value: directive_value(value, Helpers.to_meta(expr_meta, meta)),
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract({":arg", value, attr_meta}, meta) do
    %AST.Directive{
      module: __MODULE__,
      name: :arg,
      value: %AST.Literal{value: value},
      meta: Helpers.to_meta(attr_meta, meta)
    }
  end

  def extract(_, _), do: []

  def process(%AST.Directive{} = directive, %AST.Slot{} = slot) do
    value =
      case directive.value do
        %AST.Literal{value: value} -> value
        %AST.AttributeExpr{value: value} -> value
      end

    slot_name = Module.get_attribute(slot.meta.caller.module, :__slot_name__)
    default_slot_of_slotable_component? = slot.name == :default && slot_name

    if default_slot_of_slotable_component? do
      component_name = Macro.to_string(slot.meta.caller.module)

      message = """
      arguments for the default slot in a slotable component are not accessible - instead the arguments \
      from the parent's #{slot_name} slot will be exposed via `:let={...}`.

      Hint: You can remove these arguments, pull them up to the parent component, or make this component not slotable \
      and use it inside an explicit slot entry:
      ```
      <:#{slot_name}>
        <#{component_name} :let={...}>
          ...
        </#{component_name}>
      </:#{slot_name}>
      ```
      """

      IOHelper.warn(message, directive.meta.caller, directive.meta.line)
    end

    %{slot | arg: value}
  end

  defp directive_value(value, meta) do
    AST.AttributeExpr.new(
      Surface.TypeHandler.expr_to_quoted!(value, ":arg", :let_arg, meta),
      value,
      meta
    )
  end
end
