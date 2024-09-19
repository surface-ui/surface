defmodule Surface.Catalogue.Playground do
  @moduledoc """
  A generic LiveView to create a component's playground for the Surface Catalogue.

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

  ## Initializing props and slots

  If you need to define initial values for props or slots of the component, you can use
  the `@props` and `@slots` module attributes, respectively. Both attributes are optional
  and take a keyword list containing all the props/slots you need to initialize.

  Pay attention that if you have required props/slots, you should provide initial values
  for them.

  ## Example

      defmodule MyApp.Components.MyButton.Playground do
        use Surface.Catalogue.Playground,
          subject: MyApp.Components.MyButton,
          height: "170px"

        @props [
          class: "btn"
        ]

        @slots [
          default: "Cancel"
        ]
      end

  """

  import Phoenix.LiveView
  import Phoenix.Component, except: [slot: 1, slot: 2]

  @pubsub Surface.Catalogue.PubSub

  defmacro __using__(opts) do
    subject = Surface.Catalogue.fetch_subject!(opts, __MODULE__, __CALLER__)

    quote do
      @config unquote(opts)
      @after_compile unquote(__MODULE__)
      @__use_line__ unquote(__CALLER__.line)
      @before_compile unquote(__MODULE__)

      use Surface.LiveView, unquote(opts)

      alias unquote(subject)
      require Surface.Catalogue.Data, as: Data

      @impl true
      def mount(params, session, socket) do
        unquote(__MODULE__).__mount__(params, session, socket, unquote(subject))
      end

      @impl true
      def handle_info(message, socket) do
        unquote(__MODULE__).__handle_info__(message, socket)
      end

      @impl true
      def render(var!(assigns)) do
        unquote(__MODULE__).inject_render()
      end

      defoverridable(render: 1)
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
    if running_pubsub?() do
      Phoenix.PubSub.subscribe(@pubsub, topic(window_id))
    end
  end

  defp notify_init(window_id, subject, props, slots, events, assigns_values) do
    if running_pubsub?() do
      message = {:playground_init, self(), subject, props, slots, events, assigns_values}
      Phoenix.PubSub.broadcast(@pubsub, topic(window_id), message)
    end
  end

  defp notify_event_received(window_id, event, value, props) do
    if running_pubsub?() do
      message = {:playground_event_received, event, value, props}
      Phoenix.PubSub.broadcast(@pubsub, topic(window_id), message)
    end
  end

  defp topic(window_id) do
    "#{@pubsub}:#{window_id}"
  end

  defmacro __before_compile__(env) do
    config = Module.get_attribute(env.module, :config)
    subject = Keyword.fetch!(config, :subject)

    props_data = Module.get_attribute(env.module, :props, [])
    slots_data = Module.get_attribute(env.module, :slots, [])

    common_ast =
      quote do
        @moduledoc catalogue: [
                     type: :playground,
                     subject: unquote(subject),
                     config: unquote(config)
                   ]

        data props, :keyword, default: unquote(Macro.escape(props_data))
        data slots, :keyword, default: unquote(slots_data)
      end

    if Module.defines?(env.module, {:handle_event, 3}) do
      quote do
        unquote(common_ast)

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
        unquote(common_ast)

        @impl true
        def handle_event(event, value, socket) do
          unquote(__MODULE__).__handle_event__(event, value, socket)
        end
      end
    end
  end

  def __after_compile__(env, _) do
    case Module.get_attribute(env.module, :config)[:catalogue] do
      nil ->
        nil

      module ->
        case Code.ensure_compiled(module) do
          {:module, _mod} ->
            nil

          {:error, _} ->
            message =
              "defined catalogue `#{inspect(module)}` could not be found"

            Surface.IOHelper.compile_error(message, env.file, Module.get_attribute(env.module, :__use_line__))
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

      slots = Enum.map(subject.__slots__(), &Map.put(&1, :type, :string))

      events_props_values = generate_events_props(events)

      props_values =
        props
        |> get_props_default_values()
        |> Map.merge(Map.new(socket.assigns.props))
        |> Map.merge(events_props_values)

      slots_values =
        slots
        |> init_slots_values()
        |> Map.merge(Map.new(socket.assigns.slots))

      assigns_values = Map.merge(props_values, slots_values)

      notify_init(window_id, subject, props, slots, events, assigns_values)

      {:ok, assign(socket, subject: subject, props: props_values, slots: slots_values)}
    else
      {:ok, socket}
    end
  end

  @doc false
  def __handle_info__({:update_props, values}, socket) do
    props_names = Enum.map(socket.assigns.subject.__props__(), & &1.name)
    props_values = Map.take(values, props_names)
    slots_values = Map.new(socket.assigns.subject.__slots__(), fn %{name: name} -> {name, values[name]} end)

    {:noreply, assign(socket, props: props_values, slots: slots_values)}
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

  @doc false
  defmacro inject_render() do
    subject = Module.get_attribute(__CALLER__.module, :config)[:subject]
    slots = Enum.map(subject.__slots__(), & &1.name)

    render_code =
      if slots == [] do
        "<#{subject} :props={@props}/>"
      else
        slots_code =
          Enum.map_join(slots, fn slot ->
            "<:#{slot} __ignore__={is_nil(@slots[#{inspect(slot)}])}>{@slots[#{inspect(slot)}]}</:#{slot}>"
          end)

        "<#{subject} :props={@props}>#{slots_code}</#{subject}>"
      end

    render_code
    |> Surface.Compiler.compile(__CALLER__.line, __CALLER__)
    |> Surface.Compiler.to_live_struct()
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

  defp init_slots_values(slots) do
    for %{name: name} <- slots, into: %{} do
      {name, nil}
    end
  end

  defp get_props_default_values(props) do
    for %{name: name, opts: opts} <- props,
        Keyword.has_key?(opts, :default),
        into: %{} do
      {name, opts[:default]}
    end
  end

  defp running_pubsub? do
    pid = Process.whereis(@pubsub)
    pid && Process.alive?(pid)
  end
end
