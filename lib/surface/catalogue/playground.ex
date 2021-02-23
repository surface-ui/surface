defmodule Surface.Catalogue.Playground do
  @moduledoc """
  Experimental LiveView to create Playgrounds for catalogue tools.

  ## Options

  Besides the buit-in options provided by the LiveView itself, a Playground also
  provides the following options:

    * `subject` - Required. The target component of the Playground.

    * `height` - Required. The initial height of the Playground.

    * `catalogue` - Optional. A module that implements the `Surface.Catalogue`
      providing additional information to the catalogue tool. Usually required
      if you want to share your components as a library.

    * `body` - Optional. Sets/overrides the attributes of the Playground's body tag.
      Useful to set a different background or padding.

  """

  import Phoenix.LiveView

  @pubsub Surface.Catalogue.PubSub

  defmacro __using__(opts) do
    subject = Surface.Catalogue.fetch_subject!(opts, __MODULE__, __CALLER__)

    quote do
      use Surface.LiveView, unquote(opts)

      alias unquote(subject)
      require Surface.Catalogue.Data, as: Data

      @config unquote(opts)
      @before_compile unquote(__MODULE__)

      @impl true
      def mount(params, session, socket) do
        unquote(__MODULE__).__mount__(params, session, socket, unquote(subject))
      end

      @impl true
      def handle_info(message, socket) do
        unquote(__MODULE__).__handle_info__(message, socket)
      end
    end
  end

  # Retrieves or creates the window id that should be used to filter
  # PubSub messages from the Playground.
  @doc false
  def get_window_id(session, params) do
    key = "__window_id__"

    get_value_by_key(session, key) ||
      get_value_by_key(params, key) ||
      Base.encode16(:crypto.strong_rand_bytes(16))
  end

  # Subscribes to receive notification messages from the Playground.
  @doc false
  def subscribe(window_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(window_id))
  end

  defp notify_init(window_id, subject, props, events, props_values_with_events) do
    message = {:playground_init, self(), subject, props, events, props_values_with_events}
    Phoenix.PubSub.broadcast(@pubsub, topic(window_id), message)
  end

  defp notify_event_received(window_id, event, value, props) do
    message = {:playground_event_received, event, value, props}
    Phoenix.PubSub.broadcast(@pubsub, topic(window_id), message)
  end

  defp topic(window_id) do
    "#{@pubsub}:#{window_id}"
  end

  defmacro __before_compile__(env) do
    config = Module.get_attribute(env.module, :config)
    subject = Keyword.fetch!(config, :subject)

    module_doc =
      quote do
        @moduledoc catalogue: [
                     type: :playground,
                     subject: unquote(subject),
                     config: unquote(config)
                   ]
      end

    if Module.defines?(env.module, {:handle_event, 3}) do
      quote do
        unquote(module_doc)

        defoverridable handle_event: 3

        @impl true
        def handle_event(event, value, socket) do
          result = super(event, value, socket)

          socket =
            case result do
              {:noreply, socket} -> socket
              {:reply, _map, socket} -> socket
            end

          unquote(__MODULE__).__handle_event__(event, value, socket)
          result
        end
      end
    else
      quote do
        unquote(module_doc)

        @impl true
        def handle_event(event, value, socket) do
          unquote(__MODULE__).__handle_event__(event, value, socket)
        end
      end
    end
  end

  @doc false
  def __mount__(params, session, socket, subject) do
    window_id = get_window_id(session, params)
    socket = assign(socket, :__window_id__, window_id)

    if connected?(socket) do
      {events, props} =
        subject.__props__()
        |> Enum.split_with(fn prop -> prop.type == :event end)

      events_props_values = generate_events_props(events)

      props_values =
        props
        |> get_props_default_values()
        |> Map.merge(socket.assigns.props)
        |> Map.merge(events_props_values)

      notify_init(window_id, subject, props, events, props_values)

      {:ok, assign(socket, :props, props_values)}
    else
      {:ok, socket}
    end
  end

  @doc false
  def __handle_info__({:update_props, values}, socket) do
    {:noreply, assign(socket, :props, values)}
  end

  def __handle_info__(:wake_up, socket) do
    {:noreply, socket}
  end

  @doc false
  def __handle_event__(event, value, socket) do
    window_id = socket.assigns[:__window_id__]
    notify_event_received(window_id, event, value, socket.assigns.props)

    {:noreply, socket}
  end

  defp get_value_by_key(map, key) when is_map(map) do
    map[key]
  end

  defp get_value_by_key(_map, _key) do
    nil
  end

  defp generate_events_props(events) do
    for %{name: name} <- events, into: %{} do
      {name, %{name: name, target: :live_view}}
    end
  end

  defp get_props_default_values(props) do
    for %{name: name, opts: opts} <- props,
        Keyword.has_key?(opts, :default),
        into: %{} do
      {name, opts[:default]}
    end
  end
end
