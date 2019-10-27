defmodule LiveComponentLazyBuiltinTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import ComponentTestHelper
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defmodule Grid do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <table>
        <%= for item <- @items do %>
          <tr>
            <%= @inner_content.(item: item) %>
          </tr>
        <% end %>
      </table>
      """
    end
  end

  defmodule Column do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~L"""
      <td><%= @inner_content.([]) %></td>
      """
    end
  end

  defmodule View do
    use Surface.LiveView

    def render(assigns) do
      items = [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]

      ~L"""
      <%= live_component @socket, Grid, items: items do %>
        <%= live_component @socket, Column do %>
          Id: <%= @item.id %>
        <% end %>
        <%= live_component @socket, Column do %>
          Name: <%= @item.name %>
        <% end %>
      <% end %>
      """
    end
  end

  test "render inner content" do
    {:ok, _view, html} = live_isolated(build_conn(), View)

    assert_html html =~ """
    <table>
      <tr>
        <td>Id: 1</td>
        <td>Name: First</td>
      </tr>
      <tr>
        <td>Id: 2</td>
        <td>Name: Second</td>
      </tr>
    </table>
    """
  end
end
