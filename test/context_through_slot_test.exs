defmodule Surface.ContextThroughSlotTest do
  use Surface.ConnCase, async: true

  defmodule Parent.ContextProvider do
    use Surface.Component

    prop foo, :string
    slot default

    def render(assigns) do
      ~H"""
      <Context put={{ foo: @foo }}>
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
      <Context get={{ foo: foo }}>
        <div>{{ foo }}</div>
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

  test "child should take context from parent when rendered in slot", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, ExampleWeb.ContextLive)
    assert html =~ "<div><div>bar</div></div>"
  end
end
