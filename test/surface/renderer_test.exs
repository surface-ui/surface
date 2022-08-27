defmodule Surface.RendererTest do
  use Surface.ConnCase, async: true

  alias Surface.RendererTest.Components.ComponentWithExternalTemplate
  alias Surface.RendererTest.Components.ComponentWithExternalTemplateAndRenderSface
  alias Surface.RendererTest.Components.LiveComponentWithExternalTemplate
  alias Surface.RendererTest.Components.LiveComponentWithExternalTemplateAndRenderSface
  alias Surface.RendererTest.Components.LiveViewWithExternalTemplate
  alias Surface.RendererTest.Components.LiveViewWithExternalTemplateAndRenderSface

  defmodule View do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <ComponentWithExternalTemplate/>
      <ComponentWithExternalTemplateAndRenderSface/>
      <LiveComponentWithExternalTemplate id="live_component"/>
      <LiveComponentWithExternalTemplateAndRenderSface id="live_component_render_sface"/>
      <LiveViewWithExternalTemplate id="live_view" />
      <LiveViewWithExternalTemplateAndRenderSface id="live_view_render_sface" />
      """
    end
  end

  test "Component rendering external template", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the component"
  end

  test "Component rendering external template with render_sface", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the component (render_sface)"
  end

  test "LiveComponent rendering external template", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the live component"
  end

  test "LiveComponent rendering external template with render_sface", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the live component (render_sface)"
  end

  test "LiveView rendering external template", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the live view"
  end

  test "LiveView rendering external template with render_sface", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, View)
    assert html =~ "the rendered content of the live view (render_sface)"
  end
end

defmodule Surface.RendererSyncTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "emitted warning is for sface file" do
    view_code = """
    defmodule WarningTestComponent do
      use Surface.Component

      slot default, required: true
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(view_code, [], %{__ENV__ | line: 1})
      end)

    assert output =~ "setting the fallback content on a required slot has no effect"
    assert extract_line(output) == 2
    assert extract_file(output) == "test/surface/warning_test_component.sface"
  end

  defp extract_line(message) do
    case Regex.run(~r/(?:nofile|.exs|.sface):(\d+)/, message) do
      [_, line] ->
        String.to_integer(line)

      _ ->
        :not_found
    end
  end

  defp extract_file(message) do
    case Regex.run(~r/(nofile|[^\s]+.exs|[^\s]+.sface):(?:\d+)/, message) do
      [_, file] ->
        file

      _ ->
        :not_found
    end
  end
end
