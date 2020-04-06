defmodule LiveComponentTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import ComponentTestHelper

  @endpoint Endpoint

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

    data label, :string, default: "Initial stateful"

    def update(_assigns, socket) do
      {:ok, assign(socket, assigned_in_update: "Assinged in update/2")}
    end

    def render(assigns) do
      ~H"""
      <div phx-click="click" id="theDiv">{{ @label }} - {{ @assigned_in_update }}</div>
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
    use Surface.LiveComponent

    slot default, props: [:info]

    def render(assigns) do
      info = "Hi there!"

      ~H"""
        <div>
          {{ @inner_content.(info: info) }}
        </div>
      """
    end
  end

  defmodule InfoProviderWithoutSlotProps do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
        <div>
          {{ @inner_content.([]) }}
        </div>
      """
    end
  end

  test "render content without slot props" do
    code = """
    <InfoProviderWithoutSlotProps>
      <span>Hi there!</span>
    </InfoProviderWithoutSlotProps>
    """

    assert render_live(code) =~ ~r"""
           <div surface-cid=".+"><span>Hi there!</span></div>
           """
  end

  test "render content with slot props" do
    code = """
    <InfoProvider :let={{ info: my_info }}>
      <span>{{ my_info }}</span>
    </InfoProvider>
    """

    assert render_live(code) =~ ~r"""
           <div surface-cid=".+"><span>Hi there!</span></div>
           """
  end

  test "generate a different cid for each instance when using :for" do
    code = """
    <StatefulComponent:for={{ i <- [1,2] }} id={{i}} />
    """

    [cid1, cid2] =
      Regex.scan(~r/surface-cid="(.+)"/U, render_live(code))
      |> Enum.map(fn [_, cid] -> cid end)

    assert cid1 =~ ~r/^statefulcomponent-/
    assert cid2 =~ ~r/^statefulcomponent-/
    assert cid1 != cid2
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
    assert render_click([view, "theDiv"], :click) =~ "Updated stateful"
  end
end
