defmodule Surface.EventsTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import ComponentTestHelper
  import ExUnit.CaptureIO

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

  defmodule ButtonWithInvalidEvent do
    use Surface.LiveComponent

    property click, :event

    def render(assigns) do
      ~H"""
      <button phx-click={{ @click }}/>
      """
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

  test "raise error when passing an :event into a phx-* binding" do

    code =
      """
      <div>
        <ButtonWithInvalidEvent id="button_id" click={{ "ok" }}/>
      </div>
      """

    message = "invalid value for \"phx-click\". LiveView bindings only accept values " <>
              "of type :string. If you want to pass an :event, please use directive " <>
              ":on-phx-click instead. Expected a :string, got: %{name: \"ok\", target: :live_view}"

    assert_raise(RuntimeError, message, fn ->
      render_live(code)
    end)
  end

  describe "non-matching event handlers" do

    test "do not warn if there's a matching event handler" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestLiveComponent_#{id}"

      view_code = """
      defmodule #{module} do
        use Surface.LiveComponent

        def render(assigns) do
          ~H(<div><Button click="fool">OK</Button></div>)
        end

        def handle_event("fo" <> _rest, _, socket) do
          {:noreply, socket}
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 0})
        end)

      assert output == ""
    end

    test "do not warn if there's a matching event handler with guards" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestLiveComponent_#{id}"

      view_code = """
      defmodule #{module} do
        use Surface.LiveComponent

        def render(assigns) do
          ~H(<div><Button click="foo">OK</Button></div>)
        end

        def handle_event(event, _, socket) when event in ["foo", "bar"] do
          {:noreply, socket}
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 0})
        end)

      assert output == ""
    end

    test "warn if there's no matching event handler with guards" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestLiveComponent_#{id}"

      view_code = """
      defmodule #{module} do
        use Surface.LiveComponent

        def render(assigns) do
          ~H(<div><Button click="foo">OK</Button></div>)
        end

        def handle_event(event, _, socket) when event in ["bar", "baz"] do
          {:noreply, socket}
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 0})
        end)

      assert output =~
        ~r[Unhandled event "foo" \(module .+#{module} does not implement a matching handle_message/2\)]
      assert extract_line(output) == 5
    end

    test "warn if there's no matching event handler" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestLiveComponent_#{id}"

      view_code = """
      defmodule #{module} do
        use Surface.LiveComponent

        def render(assigns) do
          ~H(<div><Button click="ok">OK</Button></div>)
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 0})
        end)

      assert output =~
        ~r[Unhandled event "ok" \(module .+#{module} does not implement a matching handle_message/2\)]
      assert extract_line(output) == 5
    end

    test "do not warn when passing the event as an expression" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestLiveComponent_#{id}"

      view_code = """
      defmodule #{module} do
        use Surface.LiveComponent

        def render(assigns) do
          ~H(<div><Button click={{ "ok" }}>OK</Button></div>)
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 0})
        end)

      assert output == ""
    end

    test "prevent 'variable X is unused' warnings" do
      id = :erlang.unique_integer([:positive]) |> to_string()
      module = "TestLiveComponent_#{id}"

      view_code = """
      defmodule #{module} do
        use Surface.LiveComponent

        def render(assigns) do
          ~H(<div></div>)
        end

        def handle_event("foo" <> var, _, socket) do
          IO.inspect(var)
          {:noreply, socket}
        end

        def handle_event("bar" <> _var, _, socket) do
          {:noreply, socket}
        end

        def handle_event(<<"baz", <<var::size(2), _rest::bitstring>>::bitstring>>, _, socket) do
          IO.inspect(var)
          {:noreply, socket}
        end

        def handle_event(_var, _, socket) do
          {:noreply, socket}
        end
      end
      """

      output =
        capture_io(:standard_error, fn ->
          {{:module, _, _, _}, _} = Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 0})
        end)

      assert output == ""
    end
  end
end
