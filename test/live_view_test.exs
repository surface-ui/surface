defmodule LiveViewTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  defmodule LiveViewDataWithoutDefault do
    use Surface.LiveView

    data count, :integer

    def render(assigns) do
      ~H"""
      <div>{{ Map.has_key?(assigns, :count) }}</div>
      """
    end
  end

  test "do not set assign for `data` without default value" do
    assert render_live(LiveViewDataWithoutDefault) =~ "false"
  end
end
