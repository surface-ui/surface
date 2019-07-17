defmodule Surface.LiveComponent do
  alias Surface.Properties

  defmacro __using__(_) do
    quote do
      use Surface.Properties
      use Surface.Event

      import unquote(__MODULE__)
      import Surface.Component, only: [render_component: 2, render_component: 3]
      import Surface.Parser
      import Phoenix.LiveView

      @after_compile unquote(__MODULE__)

      @behaviour Phoenix.LiveView
      @behaviour unquote(__MODULE__)

      @impl Phoenix.LiveView
      def mount(session, socket) do
        {props, session} = Map.pop(session, :props, %{})
        props = Map.put_new(props, :content, [])
        mount(props, session, assign(socket, props: props))
      end

      @impl Phoenix.LiveView
      def render(var!(assigns)) do
        ~L"""
        <%= render(assigns.props, assigns) %>
        """
      end

      @impl unquote(__MODULE__)
      def mount(_props, _session, socket), do: {:ok, socket}

      def __component_type() do
        unquote(__MODULE__)
      end

      defoverridable mount: 3
    end
  end

  @callback mount(props :: map, session :: map, Socket.t()) ::
              {:ok, Socket.t()} | {:stop, Socket.t()}

  def __after_compile__(env, _) do
    event_references = Module.get_attribute(env.module, :event_references)
    for {event, line} <- event_references,
        !env.module.__has_event_handler?(event) do
      warn("Unhandled event \"#{event}\" (module #{inspect(env.module)} does not implement a matching handle_message/2)", env, line)
    end
  end

  def render_call(mod_str, attributes, mod, caller) do
    rendered_props = Properties.render_props(attributes, mod, mod_str, caller)
    ["live_render_component(@socket, ", mod_str, ", session: %{props: ", rendered_props, "})"]
  end

  def live_render_component(socket, module, opts) do
    do_live_render_component(socket, module, opts, [])
  end

  def live_render_component(socket, module, opts, do: block) do
    do_live_render_component(socket, module, opts, block)
  end

  def do_live_render_component(socket, module, opts, content) do
    opts = put_in(opts, [:session, :props, :content], content)
    Phoenix.LiveView.live_render(socket, module, opts)
  end

  # TODO: centralize
  def warn(message, caller, line) do
    stacktrace =
      Macro.Env.stacktrace(caller)
      |> (fn([{a, b, c, [d, {:line, _line}]}]) -> [{a, b, c, [d, {:line, line}]}] end).()
    IO.warn(message, stacktrace)
  end

end
