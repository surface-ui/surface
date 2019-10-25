defmodule Surface.LiveView do

  alias Surface.Translator

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.Binding
      use Surface.EventValidator
      use Surface.EventHandler

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def mount(_props, _session, socket), do: {:ok, socket}

      defdelegate render_code(mod_str, attributes, children_iolist, mod, caller),
        to: Surface.LiveViewRenderer

      use Phoenix.LiveView

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

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> Translator.translate(line_offset, __CALLER__)
    |> EEx.compile_string(engine: Phoenix.LiveView.Engine, line: line_offset)
  end

  defmacro event(event_name) do
    quote do
      unquote(event_name)
    end
  end
end
