defmodule LiveComponentLazyTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import ComponentTestHelper
  import Phoenix.LiveViewTest

  @endpoint Endpoint

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defmodule Column do
    use Surface.DataComponent

    property title, :string, required: true

    def bindings do
      [:item]
    end
  end

  defmodule Grid do
    use Surface.LiveComponent

    property items, :list, required: true

    def render(assigns) do
      # TODO: Do this before calling `render` and put it in the assigns
      cols = children_by_type(assigns.content, Column)

      ~H"""
      <table>
        <tr>
          <th :for={{ col <- cols }}>
            {{ col.title }}
          </th>
        </tr>
        <tr :for={{ item <- @items }}>
          <td :for={{ col <- cols }}>
            {{ col.inner_content.(item: item) }}
          </td>
        </tr>
      </table>
      """
    end
  end

  defmodule View do
    use Surface.LiveView

    def render(assigns) do
      items = [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]
      ~H"""
      <Grid items={{ items }}>
        <Column title="ID">
          Id: {{ item.id }}
        </Column>
        <Column title="NAME">
          Name: {{ item.name }}
        </Column>
      </Grid>
      """
    end
  end

  test "render inner content" do
    {:ok, _view, html} = live_isolated(build_conn(), View)

    assert_html html =~ """
    <table>
      <tr>
        <th>ID</th>
        <th>NAME</th>
      </tr>
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
