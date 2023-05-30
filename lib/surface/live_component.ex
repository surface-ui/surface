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
          ~F"\""
          <div class={"modal", "is-active": @show}>
            <div class="modal-background"></div>
            <div class="modal-card">
              <header class="modal-card-head">
                <p class="modal-card-title">{@title}</p>
              </header>
              <section class="modal-card-body">
                <#slot/>
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
      import Phoenix.Component, except: [slot: 1, slot: 2]

      use Surface.BaseComponent, type: unquote(__MODULE__)

      @before_compile unquote(__MODULE__)

      use Surface.API, include: [:prop, :slot, :data]
      import Phoenix.HTML

      @before_compile {Surface.BaseComponent, :__before_compile_init_slots__}

      alias Surface.Components.{Context, Raw}
      alias Surface.Components.Dynamic.Component
      alias Surface.Components.Dynamic.LiveComponent

      @doc """
      The id of the live component (required by LiveView for stateful components).
      """
      prop id, :string, required: true

      @doc "Built-in assign"
      data socket, :struct

      @doc "Built-in assign"
      data myself, :struct
    end
  end

  defmacro __before_compile__(env) do
    [quoted_mount(env), quoted_update(env)]
  end

  defp quoted_update(env) do
    props_specs = env.module |> Surface.API.get_props() |> Enum.reverse()
    data_specs = env.module |> Surface.API.get_data() |> Enum.reverse()

    quoted_props_assigns =
      for %{name: name, opts: opts} <- props_specs, key = opts[:from_context] do
        quote do
          updated_assigns =
            Map.put(
              updated_assigns,
              unquote(name),
              var!(assigns)[unquote(name)] || var!(assigns)[:__context__][unquote(key)]
            )
        end
      end

    quoted_data_assigns =
      for %{name: name, opts: opts} <- data_specs, key = opts[:from_context] do
        quote do
          updated_assigns = Map.put(updated_assigns, unquote(name), var!(assigns)[:__context__][unquote(key)])
        end
      end

    quoted_updated_assigns =
      quote do
        updated_assigns =
          if Map.has_key?(var!(assigns), :__context__) do
            updated_assigns = %{}
            unquote({:__block__, [], quoted_data_assigns ++ quoted_props_assigns})
            updated_assigns
          else
            %{}
          end
      end

    if Module.defines?(env.module, {:update, 2}) do
      quote do
        defoverridable update: 2

        def update(var!(assigns), socket) do
          unquote(quoted_updated_assigns)

          {assigns, socket} = Surface.LiveComponent.move_private_assigns(var!(assigns), socket)

          super(Map.merge(assigns, updated_assigns), socket)
        end
      end
    else
      quote do
        def update(var!(assigns), socket) do
          unquote(quoted_updated_assigns)

          socket =
            socket
            |> Phoenix.Component.assign(var!(assigns))
            |> Phoenix.Component.assign(updated_assigns)

          {:ok, socket}
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

  @private_assigns [:__context__, :__caller_scope_id__]
  @doc false
  def move_private_assigns(assigns, socket) do
    {
      Map.drop(var!(assigns), @private_assigns),
      Phoenix.Component.assign(socket, Map.take(var!(assigns), @private_assigns))
    }
  end
end
