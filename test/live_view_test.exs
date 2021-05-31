defmodule LiveViewTest do
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

  test "do not set assign for `data` without default value", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, LiveViewDataWithoutDefault)
    assert html =~ "false"
  end
end
