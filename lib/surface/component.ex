defmodule Surface.Component do
  @behaviour Surface.Translator.ComponentTranslator
  import Surface.Translator.ComponentTranslator
  alias Surface.Properties

  alias Surface.Translator.{Directive, NodeTranslator}

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      import Surface.Translator, only: [sigil_H: 2]
      import unquote(__MODULE__), only: [component: 2, component: 3]

      @behaviour unquote(__MODULE__)

      def translator() do
        unquote(__MODULE__)
      end

      defoverridable translator: 0
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @callback render(assigns :: map()) :: any
  @optional_callbacks begin_context: 1, end_context: 1

  def translate(mod, mod_str, attributes, directives, children, children_groups_contents, caller) do
    bindings = find_bindings(directives)
    {var, children_content} = translate_children_content(bindings, children)
    children_content = NodeTranslator.translate(children_content, caller)
    attr = {"inner_content", {:attribute_expr, [var]}, caller.line}
    new_attributes = if var, do: [attr | attributes], else: attributes
    translated_props = Properties.translate_attributes(attributes, mod, mod_str, caller)
    new_translated_props = Properties.translate_attributes(new_attributes, mod, mod_str, caller)

    [
      Directive.maybe_add_directives_begin(directives),
      maybe_add_context_begin(mod, mod_str, translated_props),
      [children_content | children_groups_contents],
      add_render_call("component", [mod_str, new_translated_props], false),
      Directive.maybe_add_directives_after_begin(directives, false),
      maybe_add_context_end(mod, mod_str, translated_props),
      Directive.maybe_add_directives_end(directives)
    ]
  end

  def component(module, assigns) do
    module.render(assigns)
  end

  def component(module, assigns, []) do
    module.render(assigns)
  end

  defp translate_children_content(_args, []) do
    {nil, []}
  end

  defp translate_children_content(args, children) do
    # TODO: Generate a var name that's harder to conflict
    var = "content_" <> generate_var_id()

    content = [
      "<% ", var, " = fn ", args, " -> %>",
      children,
      "<% end %>\n"
    ]
    {var, content}
  end

  defp find_bindings(attributes) do
    case Enum.find(attributes, fn attr -> match?({":bindings", _, _}, attr) end) do
      {":bindings", {:attribute_expr, [expr]}, _line} ->
        String.trim(expr)
      _ ->
        "[]"
    end
  end

  defp generate_var_id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> to_string()
  end
end
