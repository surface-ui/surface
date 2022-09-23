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
          ~F"\""
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
      @before_compile Surface.Renderer
      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:prop, :data]
      import Phoenix.HTML

      alias Surface.Components.{Context, Raw}
      alias Surface.Components.Dynamic.Component
      alias Surface.Components.Dynamic.LiveComponent

      @before_compile unquote(__MODULE__)

      @doc """
      Both the DOM ID and the ID to uniquely identify a LiveView. An `:id` is automatically generated
      when rendering root LiveViews but it is a required option when rendering a child LiveView.
      """
      prop id, :string, required: true

      @doc """
      An optional tuple for the HTML tag and DOM attributes to be used for the LiveView container.
      For example: `{:li, style: "color: blue;"}`. By default it uses the module definition container.
      """
      prop container, :tuple

      @doc """
      A map of binary keys with extra session data to be serialized and sent to the client.
      All session data currently in the connection is automatically available in LiveViews.
      You can use this option to provide extra data. Remember all session data is serialized
      and sent to the client, so you should always keep the data in the session to a minimum.
      For example, instead of storing a User struct, you should store the "user_id" and load
      the User when the LiveView mounts.
      """
      prop session, :map

      @doc """
      An optional flag to maintain the LiveView across live redirects, even if it is nested
      within another LiveView. If you are rendering the sticky view within your live layout,
      make sure that the sticky view itself does not use the same layout. You can do so by
      returning `{:ok, socket, layout: false}` from mount.
      """
      prop sticky, :boolean

      @doc "Built-in assign"
      data socket, :struct

      @doc "Built-in assign"
      data flash, :map

      @doc "Built-in assign"
      data live_action, :atom

      @doc "Built-in assign"
      data uploads, :list

      use Phoenix.LiveView, unquote(Keyword.put_new(opts, :log, false))
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
