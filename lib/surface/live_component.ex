defmodule Surface.LiveComponent do
  @behaviour Surface.Translator.ComponentTranslator
  import Surface.Translator.ComponentTranslator

  alias Surface.Translator.{Directive, NodeTranslator}

  defmacro __using__(_) do
    quote do
      use Phoenix.LiveComponent
      use Surface.BaseComponent
      use Surface.EventValidator
      import Surface.Translator, only: [sigil_H: 2]
      import Surface.Component, only: [component: 2, component: 3]

      @behaviour unquote(__MODULE__)

      def translator() do
        unquote(__MODULE__)
      end

      defoverridable translator: 0
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @optional_callbacks begin_context: 1, end_context: 1

  def translate(mod, mod_str, attributes, directives, children, data_children, caller) do
    {children_groups_contents, children_attributes} =
      translate_children_groups(mod, attributes, data_children, caller)

    has_children? = children != []

    # TODO: Add maybe_generate_id() to create an id automatically if there's a `handle_event`.
    # Also, it's probably better to create a directive :id instead of a property
    all_attributes = attributes ++ children_attributes
    translated_props = Surface.Properties.translate_attributes(all_attributes , mod, mod_str, caller)
    translated_props = "Keyword.new(#{translated_props})"

    [
      Directive.maybe_add_directives_begin(directives),
      maybe_add_context_begin(mod, mod_str, translated_props),
      NodeTranslator.translate(children_groups_contents, caller),
      add_render_call("live_component", ["@socket", mod_str, translated_props], has_children?),
      Directive.maybe_add_directives_after_begin(directives, true),
      NodeTranslator.translate(children, caller),
      maybe_add("<% end %>", has_children?),
      maybe_add_context_end(mod, mod_str, translated_props),
      Directive.maybe_add_directives_end(directives)
    ]
  end
end
