defmodule Surface.Components.Dynamic.LiveComponentTest do
  use Surface.ConnCase, async: true

  defmodule StatelessComponent do
    use Surface.Component

    prop label, :string

    def render(assigns) do
      ~F"""
      <div phx-click="click">{@label}</div>
      """
    end
  end

  defmodule StatefulComponent do
    use Surface.LiveComponent

    data label, :string, default: "Initial stateful"
    data assigned_in_update, :any

    def update(_assigns, socket) do
      {:ok, assign(socket, assigned_in_update: "Assinged in update/2")}
    end

    def render(assigns) do
      ~F"""
      <div :on-click="click" id="theDiv">{@label} - {@assigned_in_update}</div>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateful")}
    end
  end

  defmodule View do
    use Surface.LiveView
    alias Surface.Components.Dynamic.LiveComponent

    data label, :string, default: "Initial stateless"

    def render(assigns) do
      module = StatefulComponent

      ~F"""
      <StatelessComponent label={@label} />
      <LiveComponent module={module} id="comp" />
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateless")}
    end
  end

  test "render stateless component" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Initial stateless"
  end

  test "handle events in stateless component (handled by the live view)" do
    {:ok, view, _html} = live_isolated(build_conn(), View)
    assert render_click(view, :click) =~ "Updated stateless"
  end

  test "render LiveComponent" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Initial stateful"
  end

  test "render data assigned in update/2" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Assinged in update/2"
  end

  test "handle events in LiveComponent (handled by the component itself)" do
    {:ok, view, _html} = live_isolated(build_conn(), View)
    assert render_click(element(view, "#theDiv")) =~ "Updated stateful"
  end
end
