defmodule Surface.PluginsTest do
  use Surface.ConnCase, async: true

  defmodule BeforeMountPlugin do
    @behaviour Surface.Plugin

    def before_mount_live_component(_module, socket, opts) do
      socket = Phoenix.LiveView.assign(socket, value: 1)

      {socket, opts}
    end

    def before_mount_live_view(_module, params, session, socket, opts) do
      socket = Phoenix.LiveView.assign(socket, value: 1)

      {params, session, socket, opts}
    end
  end

  defmodule AfterMountPlugin do
    @behaviour Surface.Plugin

    def after_mount_live_component(_module, socket, opts) do
      socket = Phoenix.LiveView.assign(socket, value: 2)

      {socket, opts}
    end

    def after_mount_live_view(_module, params, session, socket, opts) do
      socket = Phoenix.LiveView.assign(socket, value: 2)

      {params, session, socket, opts}
    end
  end

  defmodule BeforeUpdatePlugin do
    @behaviour Surface.Plugin

    def before_update_live_component(_module, assigns, socket) do
      socket = Phoenix.LiveView.assign(socket, value: 1)

      {assigns, socket}
    end
  end

  defmodule AfterUpdatePlugin do
    @behaviour Surface.Plugin

    def before_update_live_component(_module, assigns, socket) do
      socket = Phoenix.LiveView.assign(socket, value: 2)

      {assigns, socket}
    end
  end

  defmodule BeforeUpdatePluginLiveComponent do
    use Surface.LiveComponent

    plugin BeforeUpdatePlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeUpdatePluginWithUpdateFunctionLiveComponent do
    use Surface.LiveComponent

    plugin BeforeUpdatePlugin

    data value, :integer

    def update(_assigns, socket) do
      assign(socket, value: 3)
    end

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule AfterUpdatePluginLiveComponent do
    use Surface.LiveComponent

    plugin AfterUpdatePlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule AfterUpdatePluginWithUpdateFunctionLiveComponent do
    use Surface.LiveComponent

    plugin AfterUpdatePlugin

    data value, :integer

    def update(_assigns, socket) do
      assign(socket, value: 3)
    end

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeAndAfterUpdatePluginLiveComponent do
    use Surface.LiveComponent

    plugin BeforeUpdatePlugin
    plugin AfterUpdatePlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeMountPluginLiveComponent do
    use Surface.LiveComponent

    plugin BeforeMountPlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeMountPluginWithMountFunctionLiveComponent do
    use Surface.LiveComponent

    plugin BeforeMountPlugin

    data value, :integer

    def mount(socket) do
      {:ok, assign(socket, value: 2)}
    end

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule AfterMountPluginLiveComponent do
    use Surface.LiveComponent

    plugin AfterMountPlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule AfterMountPluginWithMountFunctionLiveComponent do
    use Surface.LiveComponent

    plugin AfterMountPlugin

    data value, :integer

    def mount(socket) do
      {:ok, assign(socket, value: 3)}
    end

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeAndAfterMountPluginLiveComponent do
    use Surface.LiveComponent

    plugin BeforeMountPlugin
    plugin AfterMountPlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeMountPluginLiveView do
    use Surface.LiveView

    plugin BeforeMountPlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeMountPluginWithMountFunctionLiveView do
    use Surface.LiveView

    plugin BeforeMountPlugin

    data value, :integer

    def mount(_session, _params, socket) do
      {:ok, assign(socket, value: 2)}
    end

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule AfterMountPluginLiveView do
    use Surface.LiveView

    plugin AfterMountPlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule AfterMountPluginWithMountFunctionLiveView do
    use Surface.LiveView

    plugin AfterMountPlugin

    data value, :integer

    def mount(_session, _params, socket) do
      {:ok, assign(socket, value: 3)}
    end

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  defmodule BeforeAndAfterMountPluginLiveView do
    use Surface.LiveView

    plugin BeforeMountPlugin
    plugin AfterMountPlugin

    data value, :integer

    def render(assigns) do
      ~F"""
      <span>Value: {@value}</span>
      """
    end
  end

  describe "LiveComponent" do
    test "before_mount_live_component" do
      html =
        render_surface do
          ~F"""
          <BeforeMountPluginLiveComponent id="before-mount-live-component" />
          """
        end

      assert html =~ """
             <span>Value: 1</span>
             """
    end

    test "before_mount_live_component with mount function" do
      html =
        render_surface do
          ~F"""
          <BeforeMountPluginWithMountFunctionLiveComponent id="before-mount-live-component" />
          """
        end

      assert html =~ """
             <span>Value: 2</span>
             """
    end

    test "after_mount_live_component" do
      html =
        render_surface do
          ~F"""
          <AfterMountPluginLiveComponent id="after-mount-live-component" />
          """
        end

      assert html =~ """
             <span>Value: 2</span>
             """
    end

    test "after_mount_live_component with mount function" do
      html =
        render_surface do
          ~F"""
          <AfterMountPluginWithMountFunctionLiveComponent id="after-mount-live-component" />
          """
        end

      assert html =~ """
             <span>Value: 2</span>
             """
    end

    test "before_and_after_mount_live_component" do
      html =
        render_surface do
          ~F"""
          <BeforeAndAfterMountPluginLiveComponent id="before-and-after-mount-live-component" />
          """
        end

      assert html =~ """
             <span>Value: 2</span>
             """
    end

    test "before_update_live_component" do
      html =
        render_surface do
          ~F"""
          <BeforeUpdatePluginLiveComponent id="before-update-live-component" />
          """
        end

      assert html =~ """
             <span>Value: 1</span>
             """
    end

    test "after_update_live_component" do
      html =
        render_surface do
          ~F"""
          <AfterUpdatePluginLiveComponent id="after-update-live-component" />
          """
        end

      assert html =~ """
             <span>Value: 2</span>
             """
    end
  end

  describe "LiveView" do
    test "before_mount_live_view" do
      {:ok, _live_view, html} = live_isolated(build_conn(), BeforeMountPluginLiveView)

      assert html =~ "<span>Value: 1</span>"
    end

    test "before_mount_live_view with mount function" do
      {:ok, _live_view, html} =
        live_isolated(build_conn(), BeforeMountPluginWithMountFunctionLiveView)

      assert html =~ "<span>Value: 2</span>"
    end

    test "after_mount_live_view" do
      {:ok, _live_view, html} = live_isolated(build_conn(), AfterMountPluginLiveView)

      assert html =~ "<span>Value: 2</span>"
    end

    test "after_mount_live_view with mount function" do
      {:ok, _live_view, html} =
        live_isolated(build_conn(), AfterMountPluginWithMountFunctionLiveView)

      assert html =~ "<span>Value: 2</span>"
    end

    test "before_and_after_mount_live_view" do
      {:ok, _live_view, html} = live_isolated(build_conn(), BeforeAndAfterMountPluginLiveView)

      assert html =~ "<span>Value: 2</span>"
    end
  end
end
