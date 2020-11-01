defmodule Surface.Components.ForTest do
  use ExUnit.Case, async: true

  alias Surface.Components.For, warn: false

  import ComponentTestHelper

  test "iterates over the provided list" do
    code =
      quote do
        ~H"""
        <For each={{ fruit <- ["apples", "bananas", "oranges"] }}>
        <span>{{ fruit }}</span>
        </For>
        """
      end

    assert render_live(code) =~ """
           <span>apples</span>\
           <span>bananas</span>\
           <span>oranges</span>
           """
  end
end
