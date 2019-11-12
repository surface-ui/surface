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

  def translate(mod, mod_str, attributes, directives, children, data_children, caller) do
    {children_contents, children_attributes} = translate_children(directives, children, caller)

    {children_groups_contents, children_groups_attributes} =
      translate_children_groups(mod, attributes, data_children, caller)

    translated_props = Properties.translate_attributes(attributes, mod, mod_str, caller)
    all_attributes = children_attributes ++ children_groups_attributes ++ attributes
    all_translated_props = Properties.translate_attributes(all_attributes, mod, mod_str, caller)

    [
      Directive.maybe_add_directives_begin(directives),
      maybe_add_context_begin(mod, mod_str, translated_props),
      NodeTranslator.translate(children_groups_contents, caller),
      NodeTranslator.translate(children_contents, caller),
      add_render_call("component", [mod_str, all_translated_props], false),
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
end
