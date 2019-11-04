defmodule Surface.Component do
  @behaviour Surface.Translator.ComponentTranslator
  import Surface.Translator.ComponentTranslator

  alias Surface.Translator.{Directive, NodeTranslator}

  defmacro __using__(_) do
    quote do
      # TODO: Only use Phoenix.LiveComponent this if we have :phoenix_live_view installed
      use Phoenix.LiveComponent
      use Surface.BaseComponent
      import Surface.Translator, only: [sigil_H: 2]

      import unquote(__MODULE__)
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
    # TODO: Should this work?
    # using_live_view? = function_exported?(caller.module, :__live__, 0)
    using_live_view? = caller.macros[Phoenix.LiveView] != nil

    {translated_props, render_call, children, children_content} =
      if using_live_view? do
        translated_props = Surface.Properties.translate_attributes(attributes, mod, mod_str, caller)
        args = ["@socket", mod_str, "Keyword.new(#{translated_props})"]
        call = add_render_call("live_component", args, children != [])
        {translated_props, call, children, []}
      else
        {var, children_content} = translate_children_content("[]", children)
        attr = {"inner_content", {:attribute_expr, [var]}, caller.line}
        attributes =
          if var do
            [attr | attributes]
          else
            attributes
          end
        translated_props = Surface.Properties.translate_attributes(attributes, mod, mod_str, caller)
        call = add_render_call("component", [mod_str, translated_props], false)
        children_content = NodeTranslator.translate(children_content, caller)
        {translated_props, call, [], children_content}
      end

    has_children? = children != []

    [
      Directive.maybe_add_directives_begin(directives),
      maybe_add_context_begin(mod, mod_str, Surface.Properties.translate_attributes(attributes, mod, mod_str, caller)),
      [children_content | children_groups_contents],
      render_call,
      Directive.maybe_add_directives_after_begin(directives, using_live_view?),
      maybe_add(NodeTranslator.translate(children, caller), has_children?),
      maybe_add("<% end %>", has_children?),
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

  def generate_var_id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> to_string()
  end
end
