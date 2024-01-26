# Naming it as Surface.LiveView.LiveViewTest to avoid conflict with existing Surface.LiveViewTest
defmodule Surface.LiveView.LiveViewTest do
  use Surface.ConnCase, async: true

  defmodule LiveViewDataWithoutDefault do
    use Surface.LiveView

    data count, :integer

    def render(assigns) do
      ~F"""
      <div>{Map.has_key?(assigns, :count)}</div>
      """
    end
  end

  defmodule LiveViewWithProps do
    use Surface.LiveView

    data session_data, :map

    def mount(_params, session, socket) do
      {:ok, assign(socket, :session_data, session)}
    end

    def render(assigns) do
      ~F"""
      User id from session: {@session_data["user_id"]}
      """
    end
  end

  defmodule LiveViewWithPropsView do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <LiveViewWithProps
        id="123"
        container={{:span, class: "lv"}}
        session={%{"user_id" => "USER_ID"}}
        sticky/>
      """
    end
  end

  test "do not set assign for `data` without default value", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, LiveViewDataWithoutDefault)
    assert html =~ "false"
  end

  test "forward props to the underlying live_render call", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, LiveViewWithPropsView)

    [inner_live_view_tag] =
      Floki.parse_document!(html)
      |> Floki.find("span#123")

    assert Floki.attribute(inner_live_view_tag, "class") == ["lv"]
    assert Floki.attribute(inner_live_view_tag, "data-phx-sticky") == ["data-phx-sticky"]
    assert Floki.text(inner_live_view_tag) == "User id from session: USER_ID\n"
  end
end
