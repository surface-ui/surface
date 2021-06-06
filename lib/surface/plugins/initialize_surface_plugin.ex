defmodule Surface.Plugins.InitializeSurfacePlugin do
  @behaviour Surface.Plugin

  def before_mount_live_view(module, params, session, socket, opts) do
    mount(module, params, session, socket, opts)
  end

  def before_mount_live_component(module, socket, opts) do
    {_, _, socket, opts} = mount(module, %{}, %{}, socket, opts)
    {socket, opts}
  end

  defp mount(_module, params, session, socket, opts) do
    {params, session, Surface.init(socket), opts}
  end
end
