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

  defmacro __using__(opts) do
    quote do
      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:prop, :data]
      import Phoenix.HTML

      alias Surface.Constructs.{For, If}
      alias Surface.Components.Context

      @before_compile Surface.Renderer
      @before_compile unquote(__MODULE__)

      @doc "The id of the live view"
      prop id, :string, required: true

      @doc """
      The request info necessary for the view, such as params, cookie session info, etc.
      The session is signed and stored on the client, then provided back to the server
      when the client connects, or reconnects to the stateful view.
      """
      prop session, :map

      @doc "Built-in assign"
      data socket, :struct

      @doc "Built-in assign"
      data flash, :map

      @doc "Built-in assign"
      data live_action, :atom

      @doc "Built-in assign"
      data uploads, :list

      use Phoenix.LiveView, unquote(opts)
    end
  end

  defmacro __before_compile__(env) do
    quoted_mount(env)
  end

  defp quoted_mount(env) do
    defaults = env.module |> Surface.API.get_defaults() |> Macro.escape()

    if Module.defines?(env.module, {:mount, 3}) do
      quote do
        defoverridable mount: 3

        def mount(params, session, socket) do
          socket =
            socket
            |> Surface.init()
            |> assign(unquote(defaults))

          super(params, session, socket)
        end
      end
    else
      quote do
        def mount(_params, _session, socket) do
          {:ok,
           socket
           |> Surface.init()
           |> assign(unquote(defaults))}
        end
      end
    end
  end
end
