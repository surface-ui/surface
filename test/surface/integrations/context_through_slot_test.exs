defmodule Surface.ContextThroughSlotTest do
  use Surface.ConnCase, async: true

  defmodule Parent.ContextProvider do
    use Surface.Component

    prop foo, :string
    slot default

    def render(assigns) do
      ~F"""
      <Context put={foo: @foo}>
        <#slot />
      </Context>
      """
    end
  end

  defmodule Parent do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <div>
        <Parent.ContextProvider foo="bar">
          <#slot />
        </Parent.ContextProvider>
      </div>
      """
    end
  end

  defmodule Child do
    use Surface.Component

    def render(assigns) do
      # @foo is nil here
      ~F"""
      <Context get={foo: foo}>
        <div>{foo}</div>
      </Context>
      """
    end
  end

  defmodule ExampleWeb.ContextLive do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Parent>
        <Child/>
      </Parent>
      """
    end
  end

  test "child should take context from parent when rendered in slot", %{conn: conn} do
    expected = "<div><div>bar</div></div>"

    {:ok, _view, html} = live_isolated(conn, ExampleWeb.ContextLive)
    assert html =~ expected
  end
end
