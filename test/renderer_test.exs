defmodule Surface.RendererTest do
  use ExUnit.Case, async: true

  alias Surface.RendererTest.Components.ComponentWithExternalTemplate
  alias Surface.RendererTest.Components.LiveComponentWithExternalTemplate
  alias Surface.RendererTest.Components.LiveViewWithExternalTemplate

  import ComponentTestHelper

  defmodule View do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      <ComponentWithExternalTemplate/>
      <LiveComponentWithExternalTemplate/>
      <LiveViewWithExternalTemplate id="live_view" />
      """
    end
  end

  test "Component rendering external template" do
    assert render_live(View) =~ "the rendered content of the component"
  end

  test "LiveComponent rendering external template" do
    assert render_live(View) =~ "the rendered content of the live component"
  end

  test "LiveView rendering external template" do
    assert render_live(View) =~ "the rendered content of the live view"
  end
end
