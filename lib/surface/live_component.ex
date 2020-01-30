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
          <div class={{ "modal", isActive: @show }}>
            <div class="modal-background"></div>
            <div class="modal-card">
              <header class="modal-card-head">
                <p class="modal-card-title">{{ @title }}</p>
              </header>
              <section class="modal-card-body">
                {{ @inner_content.() }}
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
      use Phoenix.LiveComponent
      use Surface.BaseComponent
      use Surface.EventValidator
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @before_compile Surface.ContentHandler
      @component_type unquote(__MODULE__)

      def translator do
        Surface.Translator.LiveComponentTranslator
      end
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
          super(assigns, Phoenix.LiveView.assign(socket, :__surface__, assigns.__surface__))
        end
      end
    end
  end

  defp quoted_mount(env) do
    prefix = Module.split(env.module) |> List.last() |> String.downcase()
    default_assigns = [__surface_cid__: "#{prefix}-#{hash_id()}"]

    if Module.defines?(env.module, {:mount, 1}) do
      quote do
        defoverridable mount: 1

        def mount(socket) do
          super(assign(socket, unquote(default_assigns)))
        end
      end
    else
      quote do
        def mount(socket) do
          {:ok, assign(socket, unquote(default_assigns))}
        end
      end
    end
  end

  defp hash_id() do
    :crypto.strong_rand_bytes(4)
    |> Base.encode32(padding: false, case: :lower)
  end

  @doc """
  This optional callback is invoked in order to set up a
  context that can be retrieved for any descendent component.
  """
  @callback begin_context(props :: map()) :: map()

  @doc """
  This optional callback is invoked in order to clean up a
  context previously created in the `c:begin_context/1`.
  """
  @callback end_context(props :: map()) :: map()

  @optional_callbacks begin_context: 1, end_context: 1
end
