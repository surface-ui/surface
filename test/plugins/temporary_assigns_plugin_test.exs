defmodule Surface.Plugins.TemporaryAssignsPluginTest do
  use Surface.ConnCase, async: true
  import Phoenix.ConnTest

  defmodule ViewWithTemporaryAssigns do
    use Surface.LiveView

    data my_list, :list, default: [1, 2, 3], temporary: []

    def render(assigns) do
      ~F"""
        <ul id="my_list" phx-update="append">
          <li id={"item_#{item}"} :for={item <- @my_list}>{ item }</li>
        </ul>
      """
    end

    def handle_call({:update}, _, socket) do
      {:reply, socket, socket}
    end
  end

  defmodule ViewWithTemporaryAssignsAndMount2 do
    use Surface.LiveView

    data my_list, :list, default: [1, 2, 3], temporary: []

    def mount(_params, _session, socket) do
      {:ok, socket}
    end

    def render(assigns) do
      ~F"""
        <ul id="my_list" phx-update="append">
          <li id={"item_#{item}"} :for={ item <- @my_list }>{ item }</li>
        </ul>
      """
    end

    def handle_call({:update}, _, socket) do
      {:reply, socket, socket}
    end
  end

  defmodule ViewWithTemporaryAssignsAndMount3 do
    use Surface.LiveView

    data my_list, :list, default: [1, 2, 3], temporary: []
    data my_second_list, :list, default: [1, 2, 3]

    def mount(_params, _session, socket) do
      {:ok, socket, temporary_assigns: [my_second_list: []]}
    end

    def render(assigns) do
      ~F"""
        <ul id="my_first_list" phx-update="append">
          <li id={"first_item_#{item}"} :for={ item <- @my_list }>{ item }</li>
        </ul>
        <ul id="my_second_list" phx-update="append">
          <li id={"second_item_#{item}"} :for={ item <- @my_list }>{ item }</li>
        </ul>
      """
    end

    def handle_call({:update}, _, socket) do
      {:reply, socket, socket}
    end
  end

  describe "mounts functions" do
    test "add temporary_assign to opts with LiveView" do
      {_, _, _, opts} =
        Surface.Plugins.TemporaryAssignsPlugin.before_mount_live_view(
          ViewWithTemporaryAssigns,
          %{},
          %{},
          %Phoenix.LiveView.Socket{},
          []
        )

      assert opts == [temporary_assigns: [my_list: []]]
    end

    test "add temporary_assign to opts with LiveComponent" do
      {_socket, opts} =
        Surface.Plugins.TemporaryAssignsPlugin.before_mount_live_component(
          ViewWithTemporaryAssigns,
          %Phoenix.LiveView.Socket{},
          []
        )

      assert opts == [temporary_assigns: [my_list: []]]
    end

    test "merge temporary_assign with existing ones with LiveView" do
      actual = [temporary_assigns: [messages: []]]

      {_, _, _, opts} =
        Surface.Plugins.TemporaryAssignsPlugin.before_mount_live_view(
          ViewWithTemporaryAssigns,
          %{},
          %{},
          %Phoenix.LiveView.Socket{},
          actual
        )

      assert opts == [temporary_assigns: [messages: [], my_list: []]]
    end

    test "merge temporary_assign with existing ones with LiveComponent" do
      actual = [temporary_assigns: [messages: []]]

      {_socket, opts} =
        Surface.Plugins.TemporaryAssignsPlugin.before_mount_live_component(
          ViewWithTemporaryAssigns,
          %Phoenix.LiveView.Socket{},
          actual
        )

      assert opts == [temporary_assigns: [messages: [], my_list: []]]
    end
  end

  describe "with live view" do
    test "temporary assigns can be configured through :temporary option" do
      {:ok, live_view, html} = live_isolated(build_conn(), ViewWithTemporaryAssigns)

      assert html =~
               "<ul id=\"my_list\" phx-update=\"append\"><li id=\"item_1\">1</li>\<li id=\"item_2\">2</li>\<li id=\"item_3\">3</li>\</ul>"

      assert render(live_view) =~
               "<ul id=\"my_list\" phx-update=\"append\"><li id=\"item_1\">1</li>\<li id=\"item_2\">2</li>\<li id=\"item_3\">3</li>\</ul>"

      socket = GenServer.call(live_view.pid, {:update})

      assert socket.assigns.my_list == []
    end

    test "temporary assigns works with a mount/2 function that exists" do
      {:ok, live_view, html} = live_isolated(build_conn(), ViewWithTemporaryAssignsAndMount2)

      assert html =~
               "<ul id=\"my_list\" phx-update=\"append\"><li id=\"item_1\">1</li>\<li id=\"item_2\">2</li>\<li id=\"item_3\">3</li>\</ul>"

      assert render(live_view) =~
               "<ul id=\"my_list\" phx-update=\"append\"><li id=\"item_1\">1</li>\<li id=\"item_2\">2</li>\<li id=\"item_3\">3</li>\</ul>"

      socket = GenServer.call(live_view.pid, {:update})

      assert socket.assigns.my_list == []
    end

    test "temporary assigns works with a mount/3 function that exists" do
      {:ok, live_view, html} = live_isolated(build_conn(), ViewWithTemporaryAssignsAndMount3)

      assert html =~
               "<ul id=\"my_first_list\" phx-update=\"append\"><li id=\"first_item_1\">1</li><li id=\"first_item_2\">2</li><li id=\"first_item_3\">3</li></ul><ul id=\"my_second_list\" phx-update=\"append\"><li id=\"second_item_1\">1</li><li id=\"second_item_2\">2</li><li id=\"second_item_3\">3</li></ul>"

      assert render(live_view) =~
               "<ul id=\"my_first_list\" phx-update=\"append\"><li id=\"first_item_1\">1</li><li id=\"first_item_2\">2</li><li id=\"first_item_3\">3</li></ul><ul id=\"my_second_list\" phx-update=\"append\"><li id=\"second_item_1\">1</li><li id=\"second_item_2\">2</li><li id=\"second_item_3\">3</li></ul>"

      socket = GenServer.call(live_view.pid, {:update})

      assert socket.assigns.my_list == []
      assert socket.assigns.my_second_list == []
    end
  end
end
