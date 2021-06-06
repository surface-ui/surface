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
      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:prop, :data, :plugin]
      import Phoenix.HTML

      plugin Surface.Plugins.InitializeSurfacePlugin
      plugin Surface.Plugins.DefaultAssignsPlugin
      plugin Surface.Plugins.TemporaryAssignsPlugin

      alias Surface.Constructs.Deprecated.{For, If}
      alias Surface.Components.{Context, Raw}

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
    plugins =
      env.module
      |> Surface.API.get_plugins()
      |> Enum.map(fn {module, _opts} -> module end)

    if Module.defines?(env.module, {:mount, 3}) do
      quote do
        defoverridable mount: 3

        def mount(params, session, socket) do
          {params, session, socket, opts} =
            Surface.Plugin.before_mount_live_view(
              unquote(env.module),
              unquote(plugins),
              {params, session, socket, []}
            )

          {:ok, socket, opts} =
            case super(params, session, socket) do
              {:ok, socket} ->
                {:ok, socket, opts}

              {:ok, socket, mount_opts} when is_list(mount_opts) ->
                {:ok, socket, Surface.Plugin.merge_mount_opts(mount_opts, opts)}
            end

          {_params, _session, socket, opts} =
            Surface.Plugin.after_mount_live_view(
              unquote(env.module),
              unquote(plugins),
              {params, session, socket, opts}
            )

          {:ok, socket, opts}
        end
      end
    else
      quote do
        def mount(params, session, socket) do
          {params, session, socket, opts} =
            Surface.Plugin.before_mount_live_view(
              unquote(env.module),
              unquote(plugins),
              {params, session, socket, []}
            )

          {_params, _session, socket, opts} =
            Surface.Plugin.after_mount_live_view(
              unquote(env.module),
              unquote(plugins),
              {params, session, socket, opts}
            )

          {:ok, socket, opts}
        end
      end
    end
  end
end
