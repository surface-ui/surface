defmodule Surface.Plugins.DefaultAssignsPlugin do
  @behaviour Surface.Plugin

  def before_mount_live_view(module, params, session, socket, opts) do
    mount(module, params, session, socket, opts)
  end

  def before_mount_live_component(module, socket, opts) do
    {_, _, socket, opts} = mount(module, %{}, %{}, socket, opts)

    {socket, opts}
  end

  defp mount(module, params, session, socket, opts) do
    defaults =
      for %{name: name, opts: opts} <- module.__data__(), Keyword.has_key?(opts, :default) do
        {name, opts[:default]}
      end

    socket = Phoenix.LiveView.assign(socket, defaults)

    {params, session, socket, opts}
  end
end
