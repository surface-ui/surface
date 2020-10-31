defmodule Surface.Components.IfTest do
  use ExUnit.Case, async: true

  alias Surface.Components.If, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "renders inner if condition is truthy" do
      code =
        quote do
          ~H"""
          <If condition={{ true }}>
          <span>The inner content</span>
          <span>with multiple tags</span>
          </If>
          """
        end

      assert render_live(code) =~ """
            <span>The inner content</span>\
            <span>with multiple tags</span>
            """
    end
  end
end
