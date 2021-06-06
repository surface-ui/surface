defmodule Surface.Plugins.DefaultAssignsPluginTest do
  use Surface.ConnCase, async: true

  defmodule ViewWithDefaultAssign do
    use Surface.LiveView

    data my_list, :list, default: [1, 2, 3]

    def render(assigns) do
      ~F"""
      <div />
      """
    end
  end

  describe "mounts functions" do
    test "add default data to assigns with LiveComponent" do
      {socket, _} =
        Surface.Plugins.DefaultAssignsPlugin.before_mount_live_component(
          ViewWithDefaultAssign,
          %Phoenix.LiveView.Socket{},
          []
        )

      assert %Phoenix.LiveView.Socket{assigns: %{my_list: [1, 2, 3]}} = socket
    end

    test "add default data to assigns with LiveView" do
      {_, _, socket, _} =
        Surface.Plugins.DefaultAssignsPlugin.before_mount_live_view(
          ViewWithDefaultAssign,
          %{},
          %{},
          %Phoenix.LiveView.Socket{},
          []
        )

      assert %Phoenix.LiveView.Socket{assigns: %{my_list: [1, 2, 3]}} = socket
    end
  end
end
