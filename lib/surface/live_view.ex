defmodule Surface.LiveView do
  @behaviour Surface.Translator.ComponentTranslator
  import Surface.Translator.ComponentTranslator

  alias Surface.Translator.{Directive, NodeTranslator}

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.EventValidator
      import Surface.Translator, only: [sigil_H: 2]

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def mount(_props, _session, socket), do: {:ok, socket}

      def translator() do
        unquote(__MODULE__)
      end

      use Phoenix.LiveView

      @impl Phoenix.LiveView
      def mount(session, socket) do
        {props, session} = Map.pop(session, :props, %{})
        props = Map.put_new(props, :content, [])
        mount(props, session, assign(socket, props: props))
      end

      defoverridable mount: 3, translator: 0
    end
  end

  @callback mount(props :: map, session :: map, Socket.t()) ::
              {:ok, Socket.t()} | {:stop, Socket.t()}

  def translate(mod, mod_str, attributes, directives, children, children_groups_contents, has_children?, caller) do
    rendered_props = Surface.Properties.render_props(attributes, mod, mod_str, caller)
    session = ["session: %{props: ", "Surface.Properties.put_default_props(", rendered_props, inspect(mod), "})}"]

    [
      Directive.maybe_add_directives_begin(directives),
      maybe_add_begin_context(mod, mod_str, rendered_props),
      children_groups_contents,
      add_render_call("live_render", ["@socket", mod_str, session], has_children?),
      Directive.maybe_add_directives_after_begin(directives),
      maybe_add(NodeTranslator.translate(children, caller), has_children?),
      maybe_add("<% end %>", has_children?),
      maybe_add_end_context(mod, mod_str, rendered_props),
      Directive.maybe_add_directives_end(directives)
    ]
  end
end
