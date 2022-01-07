defmodule Surface.Components.Dynamic.LiveComponentTest do
  use Surface.ConnCase, async: true

  defmodule StatefulComponent do
    use Surface.LiveComponent

    data label, :string, default: "Initial stateful"
    data assigned_in_update, :any

    def update(_assigns, socket) do
      {:ok, assign(socket, assigned_in_update: "Assigned in update/2")}
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

  defmodule StatefulComponentWithDefaultSlot do
    use Surface.LiveComponent

    slot default

    prop label, :string

    def render(assigns) do
      ~F"""
      <div id="theDiv">
        <#slot/>
        {@label}
      </div>
      """
    end
  end

  defmodule View do
    use Surface.LiveView
    alias Surface.Components.Dynamic.LiveComponent

    def render(assigns) do
      module = StatefulComponent

      ~F"""
      <LiveComponent module={module} id="comp"/>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateless")}
    end
  end

  defmodule ViewWithInnerContent do
    use Surface.LiveView
    alias Surface.Components.Dynamic.LiveComponent

    def render(assigns) do
      module = StatefulComponentWithDefaultSlot

      ~F"""
      <LiveComponent module={module} id="comp" label="my label">
        <span>Inner</span>
      </LiveComponent>
      """
    end
  end

  test "render LiveComponent" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Initial stateful"
  end

  test "render LiveComponent and check props" do
    {:ok, _view, html} = live_isolated(build_conn(), ViewWithInnerContent)
    assert html =~ "my label"
  end

  test "render LiveComponent with default slot" do
    {:ok, _view, html} = live_isolated(build_conn(), ViewWithInnerContent)
    assert html =~ "Inner"
  end

  test "render data assigned in update/2" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Assigned in update/2"
  end

  # TODO: Uncomment when update to LV v0.17.6
  # test "handle events in LiveComponent (handled by the component itself)" do
  #   {:ok, view, _html} = live_isolated(build_conn(), View)
  #   assert render_click(element(view, "#theDiv")) =~ "Updated stateful"
  # end
end
