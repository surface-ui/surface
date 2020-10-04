defmodule Surface.EventsTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import ComponentTestHelper

  @endpoint Endpoint

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

    prop click, :event, default: "click"

    def render(assigns) do
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

    prop buttonClick, :event, default: "click"

    def render(assigns) do
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

  defmodule ButtonWithInvalidEvent do
    use Surface.LiveComponent

    prop click, :event

    def render(assigns) do
      ~H"""
      <button phx-click={{ @click }}/>
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

  test "handle event in the parent liveview" do
    {:ok, _view, html} = live_isolated(build_conn(), View)

    assert_html(
      html =~ """
      <button data-phx-component="2" phx-click="click">Click me!</button>
      """
    )
  end

  test "handle event in parent component" do
    code = """
    <div>
      <Panel id="panel_id"/>
    </div>
    """

    assert render_live(code) =~ """
           <button data-phx-component="2" phx-click="click" phx-target="1"\
           """
  end

  test "handle event locally" do
    code = """
    <div>
      <Button id="button_id"/>
    </div>
    """

    assert render_live(code) =~ """
           <button data-phx-component="1" phx-click="click" phx-target="1"\
           """
  end

  test "override target" do
    code = """
    <div>
      <Button id="button_id" click={{ %{name: "ok", target: "#comp"} }}/>
    </div>
    """

    assert render_live(code) =~ """
           phx-click="ok" phx-target="#comp"\
           """
  end

  test "override target with keyword list notation" do
    expected = """
    phx-click="ok" phx-target="#comp"\
    """

    # Event name as string
    code = """
    <div>
      <Button id="button_id" click={{ "ok", target: "#comp" }}/>
    </div>
    """

    assert render_live(code) =~ expected

    # Event name as atom
    code = """
    <div>
      <Button id="button_id" click={{ :ok, target: "#comp" }}/>
    </div>
    """

    assert render_live(code) =~ expected
  end

  test "passing event as nil does not render phx-*" do
    code = """
    <div>
      <Button id="button_id" click={{ nil }}/>
    </div>
    """

    html = render_live(code)

    assert html =~ "<button"
    refute html =~ "phx-click"
    refute html =~ "phx-target"
  end

  test "raise error when passing an :event into a phx-* binding" do
    code = """
    <div>
      <ButtonWithInvalidEvent id="button_id" click={{ "ok" }}/>
    </div>
    """

    message = """
    invalid value for "phx-click". LiveView bindings only accept values \
    of type :string. If you want to pass an :event, please use directive \
    :on-phx-click instead. Expected a :string, got: %{name: "ok", target: :live_view}\
    """

    assert_raise(RuntimeError, message, fn ->
      render_live(code)
    end)
  end
end
