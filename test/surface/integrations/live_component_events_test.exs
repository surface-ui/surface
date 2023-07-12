defmodule Surface.EventsTest do
  use Surface.ConnCase, async: true

  defmodule LiveDiv do
    use Surface.LiveComponent

    def render(assigns) do
      ~F"""
      <div>Live div</div>
      """
    end
  end

  defmodule Button do
    use Surface.LiveComponent

    prop click, :event, default: "click"

    def render(assigns) do
      ~F"""
      <button :on-click={@click}>Click me!</button>
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
      ~F"""
      <div>
        <Button id="button_id" click={@buttonClick}/>
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
      ~F"""
      <button phx-click={@click}/>
      """
    end

    def handle_event("click", _, socket) do
      {:noreply, socket}
    end
  end

  defmodule View do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
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

    assert html =~ """
           <button data-phx-component="2" phx-click="click">Click me!</button>\
           """
  end

  test "handle event in parent component" do
    html =
      render_surface do
        ~F"""
        <div>
          <Panel id="panel_id"/>
        </div>
        """
      end

    doc = parse_document!(html)

    assert js_attribute(doc, "div > button", "phx-click") == [["push", %{"event" => "click", "target" => 1}]]
  end

  test "handle event locally" do
    html =
      render_surface do
        ~F"""
        <div>
          <Button id="button_id"/>
        </div>
        """
      end

    doc = parse_document!(html)

    assert js_attribute(doc, "div > button", "phx-click") == [["push", %{"event" => "click", "target" => 1}]]
  end

  test "override target" do
    html =
      render_surface do
        ~F"""
        <div>
          <Button id="button_id" click={%{name: "ok", target: "#comp"}}/>
        </div>
        """
      end

    doc = parse_document!(html)

    assert js_attribute(doc, "div > button", "phx-click") == [["push", %{"event" => "ok", "target" => "#comp"}]]
  end

  test "override target with keyword list notation" do
    # event = html_escape(~S([["push",{"event":"ok","target":"#comp"}]]))

    expected = [["push", %{"event" => "ok", "target" => "#comp"}]]

    # Event name as string
    html =
      render_surface do
        ~F"""
        <div>
          <Button id="button_id" click={"ok", target: "#comp"}/>
        </div>
        """
      end

    doc = parse_document!(html)
    assert js_attribute(doc, "div > button", "phx-click") == expected

    # Event name as atom
    html =
      render_surface do
        ~F"""
        <div>
          <Button id="button_id" click={:ok, target: "#comp"}/>
        </div>
        """
      end

    doc = parse_document!(html)
    assert js_attribute(doc, "div > button", "phx-click") == expected
  end

  test "passing event as nil does not render phx-*" do
    html =
      render_surface do
        ~F"""
        <div>
          <Button id="button_id" click={nil}/>
        </div>
        """
      end

    assert html =~ "<button"
    refute html =~ "phx-click"
    refute html =~ "phx-target"
  end

  test "raise error when passing an :event into a phx-* binding" do
    message = """
    invalid value for "phx-click". LiveView bindings only accept values \
    of type :string. If you want to pass an :event, please use directive \
    :on-click instead. Expected a :string, got: %{name: "ok", target: :live_view}\
    """

    assert_raise(RuntimeError, message, fn ->
      render_surface do
        ~F"""
        <ButtonWithInvalidEvent id="button_id" click={"ok"}/>
        """
      end
    end)
  end
end
