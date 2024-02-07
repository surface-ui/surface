defmodule Surface.Components.Dynamic.LiveComponentTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Dynamic.LiveComponent

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

  defmodule StatefulPhoenixLiveComponent do
    use Phoenix.LiveComponent

    def update(_assigns, socket) do
      {:ok, assign(socket, assigned_in_update: "My assigned label")}
    end

    def render(assigns) do
      ~H"""
      <div>
        <span><%= @assigned_in_update %></span>
      </div>
      """
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

  defmodule StatefulComponentWithEvent do
    use Surface.LiveComponent

    prop click, :event

    def render(assigns) do
      ~F"""
      <div :on-click={@click}/>
      """
    end
  end

  defmodule View do
    use Surface.LiveView
    alias Surface.Components.Dynamic.LiveComponent

    def render(assigns) do
      ~F"""
      <LiveComponent module={StatefulComponent} id="comp"/>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateless")}
    end
  end

  defmodule ViewWithPhoenixLiveComponent do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <LiveComponent
        id="comp"
        module={StatefulPhoenixLiveComponent}
        label="My label"
      />
      """
    end
  end

  defmodule ViewWithInnerContent do
    use Surface.LiveView
    alias Surface.Components.Dynamic.LiveComponent

    def render(assigns) do
      ~F"""
      <LiveComponent module={StatefulComponentWithDefaultSlot} id="comp" label="my label">
        <span>Inner</span>
      </LiveComponent>
      """
    end
  end

  test "render LiveComponent" do
    {:ok, _view, html} = live_isolated(build_conn(), View)
    assert html =~ "Initial stateful"
  end

  test "render phoenix live component" do
    {:ok, _view, html} = live_isolated(build_conn(), ViewWithPhoenixLiveComponent)

    assert html =~ """
           <span>My assigned label</span>\
           """
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

  test "attribute values are still converted according to their types but only at runtime" do
    html =
      render_surface do
        ~F"""
        <LiveComponent module={StatefulComponentWithEvent} id="comp" click={"ok", target: "#comp"}/>
        """
      end

    doc = parse_document!(html)

    assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok", "target" => "#comp"}]]
  end

  test "handle events in LiveComponent (handled by the component itself)" do
    {:ok, view, _html} = live_isolated(build_conn(), View)
    assert render_click(element(view, "#theDiv")) =~ "Updated stateful"
  end
end
