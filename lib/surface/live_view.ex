defmodule Surface.LiveView do
  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.EventValidator
      import Surface.Translator, only: [sigil_H: 2]

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      def mount(_props, _session, socket), do: {:ok, socket}

      defdelegate render_code(node, caller),
        to: Surface.LiveViewRenderer

      use Phoenix.LiveView

      @impl Phoenix.LiveView
      def mount(session, socket) do
        {props, session} = Map.pop(session, :props, %{})
        props = Map.put_new(props, :content, [])
        mount(props, session, assign(socket, props: props))
      end

      defoverridable mount: 3, render_code: 2
    end
  end

  @callback mount(props :: map, session :: map, Socket.t()) ::
              {:ok, Socket.t()} | {:stop, Socket.t()}
end
