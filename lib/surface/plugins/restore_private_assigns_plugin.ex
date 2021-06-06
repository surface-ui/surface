defmodule Surface.Plugins.RestorePrivateAssignsPlugins do
  @behaviour Surface.Plugin

  def after_update_live_component(_module, assigns, socket) do
    Surface.BaseComponent.restore_private_assigns(socket, assigns)
  end
end
