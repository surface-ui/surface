defmodule Surface.LiveComponent do

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.Event

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
      @after_compile unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def mount(_props, _session, socket), do: {:ok, socket}

      defdelegate render_code(mod_str, attributes, children_iolist, mod, caller),
        to: Surface.LiveComponentRenderer

      import Phoenix.LiveView
      @behaviour Phoenix.LiveView

      @impl Phoenix.LiveView
      def mount(session, socket) do
        {props, session} = Map.pop(session, :props, %{})
        props = Map.put_new(props, :content, [])
        mount(props, session, assign(socket, props: props))
      end

      defoverridable mount: 3, render_code: 5
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

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> Surface.Parser.parse(line_offset)
    |> Surface.Parser.prepend_context()
    |> Surface.Parser.to_iolist(__CALLER__)
    |> IO.iodata_to_binary()
    |> EEx.compile_string(engine: Phoenix.LiveView.Engine, line: line_offset)
  end

  # TODO: centralize
  def warn(message, caller, line) do
    stacktrace =
      Macro.Env.stacktrace(caller)
      |> (fn([{a, b, c, [d, {:line, _line}]}]) -> [{a, b, c, [d, {:line, line}]}] end).()
    IO.warn(message, stacktrace)
  end
end
