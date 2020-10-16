defmodule LiveComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import ComponentTestHelper

  @endpoint Endpoint

  defmodule StatelessComponent do
    use Surface.Component

    prop label, :string

    def render(assigns) do
      ~H"""
      <div phx-click="click">{{ @label }}</div>
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
      ~H"""
      <div :on-click="click" id="theDiv">{{ @label }} - {{ @assigned_in_update }}</div>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, assign(socket, label: "Updated stateful")}
    end
  end

  defmodule View do
    use Surface.LiveView
    alias LiveComponentTest.StatelessComponent

    data label, :string, default: "Initial stateless"

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
    use Surface.Component

    slot default, props: [:info]

    def render(assigns) do
      info = "Hi there!"

      ~H"""
        <div>
          <slot :props={{ info: info }}/>
        </div>
      """
    end
  end

  defmodule InfoProviderWithoutSlotProps do
    use Surface.Component

    def render(assigns) do
      ~H"""
        <div>
          <slot/>
        </div>
      """
    end
  end

  defmodule LiveComponentWithEvent do
    use Surface.LiveComponent

    prop event, :event

    def render(assigns) do
      ~H"""
      <button :on-click={{ @event }} />
      """
    end
  end

  test "render content without slot props" do
    code = """
    <InfoProviderWithoutSlotProps>
      <span>Hi there!</span>
    </InfoProviderWithoutSlotProps>
    """

    assert render_live(code) =~ """
           <div><span>Hi there!</span></div>
           """
  end

  test "render content with slot props" do
    code = """
    <InfoProvider :let={{ info: my_info }}>
      <span>{{ my_info }}</span>
    </InfoProvider>
    """

    assert render_live(code) =~ """
           <div><span>Hi there!</span></div>
           """
  end

  test "render stateful component with event" do
    code = """
    <LiveComponentWithEvent event="click-event" id="button" />
    """

    assert render_live(code) =~ """
           <button data-phx-component=\"1\" phx-click=\"click-event\"></button>
           """
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
