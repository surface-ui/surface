defmodule SlotTest do
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
    use Surface.Component, slot: "inner"

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

  defmodule OuterWithDefaultSlotAndProps do
    use Surface.Component

    slot default, props: [:info]

    def render(assigns) do
      ~H"""
      <div>
        {{ @inner_content.(info: "Info from slot") }}
      </div>
      """
    end
  end

  defmodule OuterWithoutDefaultSlot do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <div>
        {{ @inner_content.(info: "Info from slot") }}
      </div>
      """
    end
  end

  defmodule Column do
    use Surface.Component, slot: "cols"

    property title, :string, required: true

    def render(assigns), do: ~H()
  end

  defmodule Grid do
    use Surface.LiveComponent

    property items, :list, required: true

    slot cols, props: [:info, item: ^items]

    def render(assigns) do
      assigns = Map.put(assigns, :__surface_cid__, "table")
      info = "Some info from Grid"
      ~H"""
      <table>
        <tr>
          <th :for={{ col <- @cols }}>
            {{ col.title }}
          </th>
        </tr>
        <tr :for={{ item <- @items }}>
          <td :for={{ col <- @cols }}>
            {{ col.inner_content.(item: item, info: info) }}
          </td>
        </tr>
      </table>
      """
    end
  end

  test "render inner content without slot props" do
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

  test "render inner content with slot props containing parent bindings" do
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

  test "render inner content renaming slot props" do
    assigns = %{items: [%{id: 1, name: "First"}]}
    code =
      """
      <Grid items={{ user <- @items }}>
        <Column title="ID" :let={{ item: my_user }}>
          <b>Id: {{ my_user.id }}</b>
        </Column>
        <Column title="NAME" :let={{ info: my_info }}>
          Name: {{ user.name }}
          Info: {{ my_info }}
        </Column>
      </Grid>
      """

    assert_html render_live(code, assigns) =~ """
    <table surface-cid="table">
      <tr>
        <th>ID</th><th>NAME</th>
      </tr><tr>
        <td><b>Id: 1</b></td>
        <td>Name: First
        Info: Some info from Grid</td>
      </tr>
    </table>
    """
  end

  test "raise compile error for undefined slot props" do
    assigns = %{items: [%{id: 1, name: "First"}]}
    code =
      """
      <Grid items={{ user <- @items }}>
        <Column title="ID" :let={{ item: my_user, non_existing: 1}}>
          <b>Id: {{ my_user.id }}</b>
        </Column>
      </Grid>
      """

    message = """
    code:2: undefined prop `:non_existing` for slot `cols` in `SlotTest.Column`. \
    Existing props are: [:item, :info].
    Hint: You can define a new slot prop using the `props` option: \
    `slot cols, props: [..., :non_existing]`\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code, assigns)
    end)
  end

  test "render default inner_content with slot props" do
    code =
      """
      <OuterWithDefaultSlotAndProps :let={{ info: my_info }}>
        Info: {{ my_info }}
      </OuterWithDefaultSlotAndProps>
      """

    assert_html render_live(code) == """
    <div>
      Info: Info from slot
    </div>
    """
  end

  test "raise compile error when using :let and there's no default slot defined" do
    code =
      """
      <OuterWithoutDefaultSlot :let={{ info: my_info }}>
        Info: {{ my_info }}
      </OuterWithoutDefaultSlot>
      """

    message =
      """
      code:1: there's no `default` slot defined in `SlotTest.OuterWithoutDefaultSlot`. \
      Directive :let can only be used on explicitly defined slots.
      Hint: You can define a `default` slot and its props using: \
      `slot default, props: [:info]\
      """

      assert_raise(CompileError, message, fn ->
        render_live(code)
      end)
  end

  test "raise compile error when using :let with undefined props for default slot" do
    code =
      """
      <OuterWithDefaultSlotAndProps :let={{ info: my_info, non_existing: 1 }}>
        Info: {{ my_info }}
      </OuterWithDefaultSlotAndProps>
      """

    message =
      """
      code:1: undefined prop `:non_existing` for slot `default` in \
      `SlotTest.OuterWithDefaultSlotAndProps`. Existing props are: [:info].
      Hint: You can define a new slot prop using the `props` option: \
      `slot default, props: [..., :non_existing]`\
      """

      assert_raise(CompileError, message, fn ->
        render_live(code)
      end)
  end

  test "raise compile error if parent component does not define any slots" do
    code =
      """
      <StatefulComponent>
        <InnerData/>
      </StatefulComponent>
      """

    message = "code:2: there's no slot `inner` defined in parent `SlotTest.StatefulComponent`"

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end

  test "raise compile error if parent component does not define the slot" do
    code =
      """
      <Grid items={{[]}}>
        <InnerData/>
      </Grid>
      """

    message =
      """
      code:2: there's no slot `inner` defined in parent `SlotTest.Grid`. \
      Existing slots are: [:cols]\
      """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end
end
