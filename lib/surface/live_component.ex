defmodule Surface.LiveComponent do
  @moduledoc """
  A live stateful component. A wrapper around `Phoenix.LiveComponent`.

  ## Example

      defmodule Dialog do
        use Surface.LiveComponent

        prop title, :string, required: true

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

  alias Surface.BaseComponent

  defmacro __using__(_) do
    quote do
      @before_compile Surface.Renderer
      use Phoenix.LiveComponent

      use Surface.BaseComponent, type: unquote(__MODULE__)

      @before_compile unquote(__MODULE__)

      use Surface.API, include: [:prop, :slot, :data]
      import Phoenix.HTML

      alias Surface.Constructs.{For, If}
      alias Surface.Components.Context

      @doc """
      The id of the live component (required by LiveView for stateful components).
      """
      prop id, :string, required: true

      @doc "Built-in assign"
      data socket, :struct

      @doc "Built-in assign"
      data flash, :map

      @doc "Built-in assign"
      data myself, :struct
    end
  end

  defmacro __before_compile__(env) do
    [quoted_mount(env), quoted_update(env)]
  end

  defp quoted_update(env) do
    if Module.defines?(env.module, {:update, 2}) do
      quote do
        defoverridable update: 2

        def update(assigns, socket) do
          {:ok, socket} = super(assigns, socket)
          {:ok, BaseComponent.restore_private_assigns(socket, assigns)}
        end
      end
    end
  end

  defp quoted_mount(env) do
    defaults = env.module |> Surface.API.get_defaults() |> Macro.escape()

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
end
