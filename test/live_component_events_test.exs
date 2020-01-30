defmodule Surface.EventsTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import ComponentTestHelper

  @endpoint Endpoint

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defmodule LiveDiv do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
      <div>Live div</div>
      """
    end
  end

  defmodule Button do
    use Surface.LiveComponent

    property click, :event, default: "click"

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "button")
      ~H"""
      <button :on-phx-click={{ @click }}>Click me!</button>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, socket}
    end
  end

  defmodule Panel do
    use Surface.LiveComponent

    property buttonClick, :event, default: "click"

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "panel")
      ~H"""
      <div>
        <Button id="button_id" click={{ @buttonClick }}/>
      </div>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, socket}
    end
  end

  defmodule View do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      <div>
        <Panel id="panel_id" buttonClick="click"/>
      </div>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, socket}
    end
  end

  test "automatically generate surface-cid for live components" do
    assert render_live("<LiveDiv/>") =~ ~r(<div surface-cid="livediv-.{7}">Live div</div>)
  end

  test "handle event in the parent liveview" do
    {:ok, _view, html} = live_isolated(build_conn(), View)

    assert_html html =~ """
    <button surface-cid="button" phx-click="click" data-phx-component="1">Click me!</button>
    """
  end

  test "handle event in parent component" do
    code =
      """
      <div>
        <Panel id="panel_id"/>
      </div>
      """

    assert render_live(code) =~ """
    <button surface-cid="button" phx-click="click" phx-target="[surface-cid=panel]"\
    """
  end

  test "handle event locally" do
    code =
      """
      <div>
        <Button id="button_id"/>
      </div>
      """

    assert render_live(code) =~ """
    <button surface-cid="button" phx-click="click" phx-target="[surface-cid=button]"\
    """
  end

  test "override target" do
    code =
      """
      <div>
        <Button id="button_id" click={{ %{name: "ok", target: "#comp"} }}/>
      </div>
      """

    assert render_live(code) =~ """
    phx-click="ok" phx-target="#comp"\
    """
  end

  test "override target with keyword list notation" do
    code =
      """
      <div>
        <Button id="button_id" click={{ "ok", target: "#comp" }}/>
      </div>
      """

    assert render_live(code) =~ """
    phx-click="ok" phx-target="#comp"\
    """
  end
end
