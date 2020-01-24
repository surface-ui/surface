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

    def mount(_params, _session, socket) do
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

  defmodule InfoProvider do
    use Surface.LiveComponent

    def render(assigns) do
      info = "Hi there!"
      ~H"""
        <div>
          {{ @inner_content.(info: info) }}
        </div>
      """
    end
  end

  defmodule InfoProviderWithoutBindings do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
        <div>
          {{ @inner_content.() }}
        </div>
      """
    end
  end

  defmodule ViewInnerContentWithoutBindings do
    use Surface.LiveView
    alias LiveComponentTest.InfoProvider

    def render(assigns) do
      ~H"""
      <InfoProviderWithoutBindings>
        <span>Hi there!</span>
      </InfoProviderWithoutBindings>
      """
    end
  end

  defmodule ViewInnerContentWithBindings do
    use Surface.LiveView
    alias LiveComponentTest.InfoProvider

    def render(assigns) do
      ~H"""
      <InfoProvider :bindings={{ info: my_info }}>
        <span>{{ my_info }}</span>
      </InfoProvider>
      """
    end
  end

  test "render content without bindings" do
    {:ok, _view, html} = live_isolated(build_conn(), ViewInnerContentWithoutBindings)
    assert html =~ "<div><span>Hi there!</span></div>"
  end

  test "render content with bindings" do
    {:ok, _view, html} = live_isolated(build_conn(), ViewInnerContentWithBindings)
    assert html =~ "<div><span>Hi there!</span></div>"
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
