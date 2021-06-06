defmodule Surface.Plugin do
  @type assigns :: Phoenix.LiveView.Socket.assigns()
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()
  @type session :: map()
  @type socket :: Phoenix.LiveView.Socket.t()

  @callback before_mount_live_view(
              module(),
              unsigned_params() | :not_mounted_at_router,
              session(),
              socket(),
              list(keyword())
            ) ::
              {
                unsigned_params() | :not_mounted_at_router,
                session(),
                socket(),
                list(keyword())
              }

  @callback after_mount_live_view(
              module(),
              unsigned_params() | :not_mounted_at_router,
              session(),
              socket(),
              list(keyword())
            ) ::
              {
                unsigned_params() | :not_mounted_at_router,
                session(),
                socket(),
                list(keyword())
              }

  @callback before_mount_live_component(
              module(),
              socket(),
              list(keyword())
            ) ::
              {
                socket(),
                list(keyword())
              }

  @callback after_mount_live_component(
              module(),
              socket(),
              list(keyword())
            ) ::
              {
                socket(),
                list(keyword())
              }

  @callback before_update_live_component(
              module(),
              assigns(),
              socket()
            ) ::
              {
                assigns(),
                socket()
              }

  @callback after_update_live_component(
              module(),
              assigns(),
              socket()
            ) ::
              {
                assigns(),
                socket()
              }

  @optional_callbacks before_mount_live_view: 5,
                      after_mount_live_view: 5,
                      before_mount_live_component: 3,
                      after_mount_live_component: 3,
                      before_update_live_component: 3,
                      after_update_live_component: 3

  def before_update_live_component(module, plugins, initial_acc) do
    Enum.reduce(plugins, initial_acc, fn plugin, {assigns, socket} = acc ->
      if function_exported?(plugin, :before_update_live_component, 3) do
        plugin.before_update_live_component(module, assigns, socket)
      else
        acc
      end
    end)
  end

  def after_update_live_component(module, plugins, initial_acc) do
    {_assigns, socket} =
      Enum.reduce(plugins, initial_acc, fn plugin, {assigns, socket} = acc ->
        if function_exported?(plugin, :after_update_live_component, 3) do
          {assigns, plugin.after_update_live_component(module, assigns, socket)}
        else
          acc
        end
      end)

    socket
  end

  def before_mount_live_component(module, plugins, initial_acc) do
    Enum.reduce(plugins, initial_acc, fn plugin, {socket, opts} = acc ->
      if function_exported?(plugin, :before_mount_live_component, 3) do
        plugin.before_mount_live_component(module, socket, opts)
      else
        acc
      end
    end)
  end

  def after_mount_live_component(module, plugins, initial_acc) do
    Enum.reduce(plugins, initial_acc, fn plugin, {socket, opts} = acc ->
      if function_exported?(plugin, :after_mount_live_component, 3) do
        plugin.after_mount_live_component(module, socket, opts)
      else
        acc
      end
    end)
  end

  def before_mount_live_view(module, plugins, initial_acc) do
    Enum.reduce(plugins, initial_acc, fn plugin, {params, session, socket, opts} = acc ->
      if function_exported?(plugin, :before_mount_live_view, 5) do
        plugin.before_mount_live_view(module, params, session, socket, opts)
      else
        acc
      end
    end)
  end

  def after_mount_live_view(module, plugins, initial_acc) do
    Enum.reduce(plugins, initial_acc, fn plugin, {params, session, socket, opts} = acc ->
      if function_exported?(plugin, :after_mount_live_view, 5) do
        plugin.after_mount_live_view(module, params, session, socket, opts)
      else
        acc
      end
    end)
  end

  def merge_mount_opts(k1, k2) do
    Keyword.merge(k1, k2, fn
      :layout, _v1, v2 -> v2
      :temporary_assigns, v1, v2 when is_list(v1) and is_list(v2) -> Keyword.merge(v1, v2)
    end)
  end
end
