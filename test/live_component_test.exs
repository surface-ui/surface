defmodule LiveComponentTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defmodule StatelessComponent do
    use Surface.LiveComponent

    property label, :string

    def render(assigns) do
      ~H"""
      <div phx-click="click">{{ @label }}</div>
      """
    end
  end

  defmodule StatefulComponent do
    use Surface.LiveComponent

    def mount(socket) do
      {:ok, assign(socket, label: "Initial stateful")}
    end

    def render(assigns) do
      ~H"""
      <div phx-click="click" id="theDiv">{{ @label }}</div>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateful")}
    end
  end

  defmodule View do
    use Surface.LiveView
    alias LiveComponentTest.StatelessComponent

    def mount(_props, _session, socket) do
      {:ok, assign(socket, label: "Initial stateless")}
    end

    def render(assigns) do
      ~H"""
      <StatelessComponent label={{ @label }} />
      <StatefulComponent id="comp" />
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

  test "handle events in LiveComponent (handled by the component itself)" do
    {:ok, view, _html} = live_isolated(build_conn(), View)
    assert render_click([view, "theDiv"], :click) =~ "Updated stateful"
  end
end
