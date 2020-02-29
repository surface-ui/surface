defmodule DataComponentTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import ComponentTestHelper

  setup_all do
    Endpoint.start_link()
    :ok
  end

  defmodule StatefulComponent do
    use Surface.LiveComponent

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "stateful")
      ~H"""
      <div>Stateful</div>
      """
    end
  end

  defmodule InnerData do
    use Surface.DataComponent, name: "inner"

    property label, :string
  end

  defmodule Outer do
    use Surface.LiveComponent

    slot default
    slot inner

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "outer")

      ~H"""
      <div>
        <div :for={{ data <- @inner }}>
          {{ data.label }}: {{ data.inner_content.() }}
        </div>
        <div>
          {{ @inner_content.() }}
        </div>
      </div>
      """
    end
  end

  defmodule Column do
    use Surface.DataComponent, name: "cols"

    property title, :string, required: true
  end

  defmodule Grid do
    use Surface.LiveComponent

    property items, :list, required: true, binding: :item

    slot cols, use_bindings: [:item]

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "table")

      ~H"""
      <table>
        <tr>
          <th :for={{ col <- @cols }}>
            {{ col.title }}
          </th>
        </tr>
        <tr :for={{ item <- @items }}>
          <td :for={{ col <- @cols }}>
            {{ col.inner_content.(item) }}
          </td>
        </tr>
      </table>
      """
    end
  end

  test "render inner content with no bindings" do
    code =
      """
      <Outer>
        Content 1
        <InnerData label="label 1">
          <b>content 1</b>
          <StatefulComponent id="stateful1"/>
        </InnerData>
        Content 2
          Content 2.1
        <InnerData label="label 2">
          <b>content 2</b>
        </InnerData>
        Content 3
        <StatefulComponent id="stateful2"/>
      </Outer>
      """

    assert_html render_live(code) =~ """
    <div surface-cid="outer">
      <div>
        label 1:<b>content 1</b>
        <div surface-cid="stateful" data-phx-component="0">Stateful</div>
      </div>
      <div>
        label 2:<b>content 2</b>
      </div>
      <div>
        Content 1
        Content 2
          Content 2.1
        Content 3
        <div surface-cid="stateful" data-phx-component="1">Stateful</div>
      </div>
    </div>
    """
  end

  test "render inner content" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}
    code =
      """
      <Grid items={{ user <- @items }}>
        <Column title="ID">
          <b>Id: {{ user.id }}</b>
        </Column>
        <Column title="NAME">
          Name: {{ user.name }}
        </Column>
      </Grid>
      """

    assert_html render_live(code, assigns) =~ """
    <table surface-cid="table">
      <tr>
        <th>ID</th><th>NAME</th>
      </tr><tr>
        <td><b>Id: 1</b></td>
        <td>Name: First</td>
      </tr><tr>
        <td><b>Id: 2</b></td>
        <td>Name: Second</td>
      </tr>
    </table>
    """
  end
end
