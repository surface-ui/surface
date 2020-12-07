defmodule Surface.RendererTest do
  use Surface.ConnCase, async: true

  alias Surface.RendererTest.Components.ComponentWithExternalTemplate
  alias Surface.RendererTest.Components.LiveComponentWithExternalTemplate
  alias Surface.RendererTest.Components.LiveViewWithExternalTemplate

  defmodule View do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      <ComponentWithExternalTemplate/>
      <LiveComponentWithExternalTemplate id="live_component"/>
      <LiveViewWithExternalTemplate id="live_view" />
      """
    end
  end

  test "Component rendering external template", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the component"
  end

  test "LiveComponent rendering external template", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the live component"
  end

  test "LiveView rendering external template", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the live view"
  end
end
