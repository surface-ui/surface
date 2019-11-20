defmodule Surface.LiveView do
  @behaviour Surface.Translator.ComponentTranslator
  import Surface.Translator.ComponentTranslator

  alias Surface.Translator
  alias Surface.Translator.Directive

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.EventValidator
      import Surface.Translator, only: [sigil_H: 2]
      import Surface.Component, only: [component: 2, component: 3]

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

  def translate(mod, mod_str, attributes, directives, children, _children_groups_contents, caller) do
    has_children? = children != []

    translated_session_props = Surface.Properties.translate_attributes(attributes, mod, mod_str, caller)

    # TODO: Replace this. Create a directive :id?
    live_view_id = :erlang.unique_integer([:positive, :monotonic]) |> to_string()

    session = ["session: %{props: ", translated_session_props, "}, id: \"live_view_", live_view_id, "\""]

    [
      Directive.maybe_add_directives_begin(directives),
      add_require(mod_str),
      add_render_call("live_render", ["@socket", mod_str, session], has_children?),
      maybe_add(Translator.translate(children, caller), has_children?),
      maybe_add("<% end %>", has_children?),
      Directive.maybe_add_directives_end(directives)
    ]
  end
end
