defmodule Surface.ContextThroughSlotTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper

  defmodule Parent.ContextProvider do
    use Surface.Component

    property foo, :string
    slot default

    def render(assigns) do
      ~H"""
      <Context :set={{ :foo, @foo }}>
        <slot />
      </Context>
      """
    end
  end

  defmodule Parent do
    use Surface.Component

    slot default

    def render(assigns) do
      ~H"""
      <div>
        <Parent.ContextProvider foo="bar">
          <slot />
        </Parent.ContextProvider>
      </div>
      """
    end
  end

  defmodule Child do
    use Surface.Component

    def render(assigns) do
      # @foo is nil here
      ~H"""
      <Context :get={{ :foo }}>
        <div>{{ @foo }}</div>
      </Context>
      """
    end
  end

  defmodule ExampleWeb.ContextLive do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
        <Parent>
          <Child/>
        </Parent>
      """
    end
  end

  test "child should take context from parent when rendered in slot" do
    assert render_live(ExampleWeb.ContextLive) =~ "<div><div>bar</div></div>"
  end
end
