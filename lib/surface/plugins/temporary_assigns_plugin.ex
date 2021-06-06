defmodule Surface.Plugins.TemporaryAssignsPlugin do
  @behaviour Surface.Plugin

  def before_mount_live_view(module, params, session, socket, opts) do
    mount(module, params, session, socket, opts)
  end

  def before_mount_live_component(module, socket, opts) do
    {_, _, socket, opts} = mount(module, %{}, %{}, socket, opts)
    {socket, opts}
  end

  defp mount(module, params, session, socket, opts) do
    temporary_assigns =
      for %{name: name, opts: opts} <- module.__data__(), Keyword.has_key?(opts, :temporary) do
        {name, opts[:temporary]}
      end

    opts = Surface.Plugin.merge_mount_opts(opts, temporary_assigns: temporary_assigns)

    {params, session, socket, opts}
  end
end
