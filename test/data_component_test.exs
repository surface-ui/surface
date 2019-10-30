defmodule DataComponentTest do
  use ExUnit.Case
  import ComponentTestHelper
  import Surface.Component
  import Surface.BaseComponent

  defmodule Outer do
    use Surface.Component

    def render(assigns) do
      children = children_by_type(assigns.content, DataComponentTest.Inner)
      ~H"""
      <div>
      <%= for child <- children do %>
        <span><%= child.value %></span>
      <% end %>
      </div>
      """
    end
  end

  defmodule Inner do
    use Surface.Component

    property value, :string, required: true

    def render(assigns) do
      {:data, assigns}
    end
  end

  defmodule OuterLazy do
    use Surface.Component

    property items, :list, required: true

    def render(assigns) do
      children = children_by_type(assigns.content, DataComponentTest.InnerLazy)
      ~H"""
      <div>
      <%= for item <- @items do %>
      <%= for child <- children do %>
        <span><%= child[:func].(item) %></span>
      <% end %>
      <% end %>
      </div>
      """
    end
  end

  defmodule InnerLazy do
    use Surface.Component
    alias Surface.BaseComponent.LazyContent

    property item, :any, lazy: true

    def render(assigns) do
      [%LazyContent{func: func}|_] = non_empty_children(assigns.content)
      {:data, Map.put(assigns, :func, func)}
    end
  end

  test "render data from children" do
    assigns = %{}
    code =
      ~H"""
      <Outer>
        <Inner value="First"/>
        <Inner value="Second"/>
      </Outer>
      """

    assert render_surface(code) =~ """
    <div>
      <span>First</span>
      <span>Second</span>
    </div>
    """
  end

  test "render lazy content from children" do
    assigns = %{}
    items = [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]
    code =
      ~H"""
      <OuterLazy items={{ items }}>
        <InnerLazy item="item">Id: {{ item.id }}</InnerLazy>
        <InnerLazy item="item">Name: {{ item.name }}</InnerLazy>
      </OuterLazy>
      """

    assert render_surface(code) =~ """
    <div>
      <span>Id: 1</span>
      <span>Name: First</span>
      <span>Id: 2</span>
      <span>Name: Second</span>
    </div>
    """
  end
end
