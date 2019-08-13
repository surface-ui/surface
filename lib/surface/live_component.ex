defmodule Surface.LiveComponent do

  alias Surface.Translator

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.Binding
      use Surface.Event
      use Surface.LiveEventHandler

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
      # @after_compile unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def mount(_props, _session, socket), do: {:ok, socket}

      defdelegate render_code(mod_str, attributes, children_iolist, mod, caller),
        to: Surface.LiveComponentRenderer

      import Phoenix.LiveView
      @behaviour Phoenix.LiveView

      require Surface.LiveEngine

      @impl Phoenix.LiveView
      def mount(session, socket) do
        # IO.inspect(__children__(), label: :children)
        # IO.inspect(__bindings__(), label: :bindings)
        {props, session} = Map.pop(session, :props, %{})
        props = Map.put_new(props, :content, [])
        mount(props, session, assign(socket, props: props))
      end

      defoverridable mount: 3, render_code: 5
    end
  end

  @callback mount(props :: map, session :: map, Socket.t()) ::
              {:ok, Socket.t()} | {:stop, Socket.t()}

  # def __after_compile__(env, _) do
  #   event_references = Module.get_attribute(env.module, :event_references)
  #   for {event, line} <- event_references,
  #       !env.module.__has_event_handler?(event) do
  #     message = "Unhandled event \"#{event}\" (module #{inspect(env.module)} does not implement a matching handle_message/2)"
  #     Surface.IO.warn(message, env, fn _ -> line end)
  #   end
  # end

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> Translator.translate(line_offset, __CALLER__)
    |> EEx.compile_string(engine: Surface.LiveEngine, line: line_offset)
    # |> EEx.compile_string(engine: Phoenix.LiveView.Engine, line: line_offset)
  end

  defmacro event(event_name) do
    quote do
      unquote(event_name)
    end
  end
end
