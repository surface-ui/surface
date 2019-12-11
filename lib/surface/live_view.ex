defmodule Surface.LiveView do
  @moduledoc """
  A wrapper component around `Phoenix.LiveView`.

  Since this module is just a wrapper around `Phoenix.LiveView`, you
  cannot define custom properties for it. Only `:id` and `:session`
  are available. However, built-in directives like `:for` and `:if`
  can be used normally.

  ## Example

      defmodule Example do
        use Surface.LiveView

        def render(assigns) do
          ~H"\""
          <Dialog title="Alert" id="dialog">
            This <b>Dialog</b> is a stateful component. Cool!
          </Dialog>

          <Button click="show_dialog">Click to open the dialog</Button>
          "\""
        end

        def handle_event("show_dialog", _, socket) do
          Dialog.show("dialog")
          {:noreply, socket}
        end
      end

  """

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.EventValidator
      import Phoenix.HTML

      property id, :integer
      property session, :map

      def translator do
        Surface.Translator.LiveViewTranslator
      end

      use Phoenix.LiveView
    end
  end

  @doc """
  The same as `Phoenix.LiveView.mount/2`.
  """
  @callback mount(session :: map, socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @doc """
  The same as `Phoenix.LiveView.render/1`.
  """
  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @doc """
  The same as `Phoenix.LiveView.terminate/2`.
  """
  @callback terminate(reason, socket :: Socket.t()) :: term
            when reason: :normal | :shutdown | {:shutdown, :left | :closed | term}

  @doc """
  The same as `Phoenix.LiveView.handle_params/3`.
  """
  @callback handle_params(Socket.unsigned_params(), uri :: String.t(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @doc """
  The same as `Phoenix.LiveView.handle_event/3`.
  """
  @callback handle_event(event :: binary, Socket.unsigned_params(), socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @doc """
  The same as `Phoenix.LiveView.handle_call/3`.
  """
  @callback handle_call(msg :: term, {pid, reference}, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:reply, term, Socket.t()} | {:stop, Socket.t()}

  @doc """
  The same as `Phoenix.LiveView.handle_info/2`.
  """
  @callback handle_info(msg :: term, socket :: Socket.t()) ::
              {:noreply, Socket.t()} | {:stop, Socket.t()}

  @optional_callbacks mount: 2,
                      terminate: 2,
                      handle_params: 3,
                      handle_event: 3,
                      handle_call: 3,
                      handle_info: 2
end
