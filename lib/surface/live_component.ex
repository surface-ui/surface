defmodule Surface.LiveComponent do
  @moduledoc """
  A live (stateless or stateful) component. A wrapper around `Phoenix.LiveComponent`.

  ## Example

      defmodule Dialog do
        use Surface.LiveComponent

        property title, :string, required: true

        def mount(socket) do
          {:ok, assign(socket, show: false)}
        end

        def render(assigns) do
          ~H"\""
          <div class={{ "modal", "is-active": @show }}>
            <div class="modal-background"></div>
            <div class="modal-card">
              <header class="modal-card-head">
                <p class="modal-card-title">{{ @title }}</p>
              </header>
              <section class="modal-card-body">
                <slot/>
              </section>
              <footer class="modal-card-foot" style="justify-content: flex-end">
                <Button click="hide">Ok</Button>
              </footer>
            </div>
          </div>
          "\""
        end

        # Public API

        def show(dialog_id) do
          send_update(__MODULE__, id: dialog_id, show: true)
        end

        # Event handlers

        def handle_event("show", _, socket) do
          {:noreply, assign(socket, show: true)}
        end

        def handle_event("hide", _, socket) do
          {:noreply, assign(socket, show: false)}
        end
      end
  """

  defmacro __using__(_) do
    quote do
      @before_compile Surface.Renderer
      use Phoenix.LiveComponent

      use Surface.BaseComponent, type: unquote(__MODULE__)

      @before_compile unquote(__MODULE__)

      use Surface.API, include: [:property, :slot, :data, :context]
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)
      require Surface.ContentHandler
      @before_compile Surface.ContentHandler
      Module.put_attribute(__MODULE__, :__is_stateful__, true)
    end
  end

  defmacro __before_compile__(env) do
    [maybe_quoted_id(env), quoted_mount(env), quoted_update(env), quoted_stateful(env)]
  end

  defp quoted_stateful(env) do
    stateful = Module.get_attribute(env.module, :__is_stateful__, false)

    quote do
      def __is_stateful__(), do: unquote(stateful)
    end
  end

  defp quoted_update(env) do
    if Module.defines?(env.module, {:update, 2}) do
      quote do
        defoverridable update: 2

        def update(assigns, socket) do
          super(assigns, Phoenix.LiveView.assign(socket, :__surface__, assigns.__surface__))
        end
      end
    end
  end

  defp quoted_mount(env) do
    defaults =
      for %{name: name, opts: opts} <- Module.get_attribute(env.module, :data) do
        {name, Keyword.get(opts, :default)}
      end
      |> Macro.escape()

    if Module.defines?(env.module, {:mount, 1}) do
      quote do
        defoverridable mount: 1

        def mount(socket) do
          super(
            socket
            |> Surface.init()
            |> assign(unquote(defaults))
          )
        end
      end
    else
      quote do
        def mount(socket) do
          {:ok,
           socket
           |> Surface.init()
           |> assign(unquote(defaults))}
        end
      end
    end
  end

  defp maybe_quoted_id(env) do
    if Module.defines?(env.module, {:handle_event, 3}) do
      quote do
        @doc """
        The id of the live component (required by LiveView).
        """
        property id, :integer, required: true
      end
    end
  end

  @doc """
  This optional callback is invoked in order to set up a
  context that can be retrieved for any descendent component.
  """
  @callback init_context(props :: map()) :: map()

  @optional_callbacks init_context: 1
end
