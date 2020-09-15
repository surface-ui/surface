defmodule Surface.SlotTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  defmodule StatefulComponent do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
      <div>Stateful</div>
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  defmodule InnerData do
    use Surface.Component, slot: "inner"

    property label, :string
  end

  defmodule OuterWithMultipleSlotableEntries do
    use Surface.Component

    slot default
    slot inner

    def render(assigns) do
      ~H"""
      <div>
        <div :for={{ {data, index} <- Enum.with_index(@inner) }}>
          {{ data.label }}: <slot name="inner" index={{ index }}/>
        </div>
        <div>
          <slot/>
        </div>
      </div>
      """
    end
  end

  defmodule OuterWithNamedSlot do
    use Surface.Component

    slot default
    slot header
    slot footer

    def render(assigns) do
      ~H"""
      <div>
        <slot name="header"/>
        <slot>
          Default fallback
        </slot>
        <slot name="footer">
          Footer fallback
        </slot>
      </div>
      """
    end
  end

  defmodule OuterWithoutDeclaringSlots do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <div>
        <slot name="header"/>
        <slot/>
        <slot name="footer"/>
      </div>
      """
    end
  end

  defmodule OuterWithNamedSlotAndProps do
    use Surface.Component

    slot body, props: [:info]

    def render(assigns) do
      ~H"""
      <div>
        <slot name="body" :props={{ info: "Info from slot" }}/>
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
        <slot :props={{ info: "Info from slot" }}/>
      </div>
      """
    end
  end

  defmodule OuterWithoutDefaultSlot do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <div></div>
      """
    end
  end

  defmodule Column do
    use Surface.Component, slot: "cols"

    property title, :string, required: true

    def render(assigns), do: ~H()
  end

  defmodule ColumnWithDefaultTitle do
    use Surface.Component, slot: "cols"

    property title, :string, default: "default title"

    def render(assigns), do: ~H()
  end

  defmodule Grid do
    use Surface.Component

    property items, :list, required: true

    slot cols, props: [:info, item: ^items]

    def render(assigns) do
      info = "Some info from Grid"

      ~H"""
      <table>
        <tr>
          <th :for={{ col <- @cols }}>
            {{ col.title }}
          </th>
        </tr>
        <tr :for={{ item <- @items }}>
          <td :for={{ {_col, index} <- Enum.with_index(@cols) }}>
            <slot name="cols" index={{ index }} :props={{ item: item, info: info }}/>
          </td>
        </tr>
      </table>
      """
    end
  end

  test "render slot without slot props" do
    code = """
    <OuterWithMultipleSlotableEntries>
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
    </OuterWithMultipleSlotableEntries>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        <div>
          label 1:<b>content 1</b>
          <div data-phx-component="1">Stateful</div>
        </div>
        <div>
          label 2:<b>content 2</b>
        </div>
        <div>
          Content 1
          Content 2
            Content 2.1
          Content 3
          <div data-phx-component="2">Stateful</div>
        </div>
      </div>
      """
    )
  end

  test "assign named slots with props" do
    code = """
    <OuterWithNamedSlotAndProps>
      <template slot="body" :let={{ :info, as: :my_info }}>
        Info: {{ @my_info }}
      </template>
    </OuterWithNamedSlotAndProps>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        Info: Info from slot
      </div>
      """
    )
  end

  test "assign default slot with props" do
    code = """
    <OuterWithDefaultSlotAndProps :let={{ :info, as: :my_info }}>
      Info: {{ @my_info }}
    </OuterWithDefaultSlotAndProps>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        Info: Info from slot
      </div>
      """
    )
  end

  test "assign default slot ignoring all props" do
    code = """
    <OuterWithDefaultSlotAndProps>
      Info
    </OuterWithDefaultSlotAndProps>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        Info
      </div>
      """
    )
  end

  test "assign named slots without props" do
    code = """
    <OuterWithNamedSlot>
      <template slot="header">
        My header
      </template>
      My body
      <template slot="footer">
        My footer
      </template>
    </OuterWithNamedSlot>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        My header
        My body
        My footer
      </div>
      """
    )
  end

  test "assign undeclared slots without props" do
    code = """
    <OuterWithoutDeclaringSlots>
      <template slot="header">
        My header
      </template>
      My body
      <template slot="footer">
        My footer
      </template>
    </OuterWithoutDeclaringSlots>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        My header
        My body
        My footer
      </div>
      """
    )
  end

  test "fallback content" do
    code = """
    <OuterWithNamedSlot/>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        Default fallback
        Footer fallback
      </div>
      """
    )
  end

  test "slotable component with default value for prop" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    code = """
    <Grid items={{ user <- @items }}>
      <ColumnWithDefaultTitle>
        <b>Id: {{ @user.id }}</b>
      </ColumnWithDefaultTitle>
    </Grid>
    """

    assert_html(
      render_live(code, assigns) =~ """
      <table>
        <tr>
          <th>default title</th>
        </tr><tr>
          <td><b>Id: 1</b></td>
        </tr><tr>
          <td><b>Id: 2</b></td>
        </tr>
      </table>
      """
    )
  end

  test "render slot with slot props containing parent bindings" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    code = """
    <Grid items={{ user <- @items }}>
      <Column title="ID">
        <b>Id: {{ @user.id }}</b>
      </Column>
      <Column title="NAME">
        Name: {{ @user.name }}
      </Column>
    </Grid>
    """

    assert_html(
      render_live(code, assigns) =~ """
      <table>
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
    )
  end

  test "render slot renaming slot props" do
    assigns = %{items: [%{id: 1, name: "First"}]}

    code = """
    <Grid items={{ user <- @items }}>
      <Column title="ID" :let={{ :item, as: :my_user }}>
        <b>Id: {{ @my_user.id }}</b>
      </Column>
      <Column title="NAME" :let={{ :info, as: :my_info }}>
        Name: {{ @user.name }}
        Info: {{ @my_info }}
      </Column>
    </Grid>
    """

    assert_html(
      render_live(code, assigns) =~ """
      <table>
        <tr>
          <th>ID</th><th>NAME</th>
        </tr><tr>
          <td><b>Id: 1</b></td>
          <td>Name: First
          Info: Some info from Grid</td>
        </tr>
      </table>
      """
    )
  end

  test "raise compile error for undefined slot props" do
    assigns = %{items: [%{id: 1, name: "First"}]}

    code = """
    <Grid items={{ user <- @items }}>
      <Column title="ID" :let={{ :item, as: :my_user }} :let={{ :non_existing, as: :value }}>
        <b>Id: {{ @my_user.id }}</b>
      </Column>
    </Grid>
    """

    message = """
    code:2: undefined prop `:non_existing` for slot `cols` in `Surface.SlotTest.Grid`.

    Available props: [:info, :item].

    Hint: You can define a new slot prop using the `props` option: \
    `slot cols, props: [..., :non_existing]`\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code, assigns)
    end)
  end

  test "raise compile error for invalid :let expression" do
    assigns = %{items: [%{id: 1, name: "First"}]}

    code = """
    <OuterWithNamedSlotAndProps>
      <template slot="body"
        :let={{ "a_string" }}>
        Info: {{ @my_info }}
      </template>
    </OuterWithNamedSlotAndProps>
    """

    message = """
    code:3: invalid value for directive :let. \
    Expected a mapping from a slot prop to an assign, \
    e.g. {{ :item }} or {{ :item, as: :user }}, got: {{ "a_string" }}.\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code, assigns)
    end)
  end

  test "raise compile error when using :let and there's no default slot defined" do
    code = """
    <OuterWithoutDefaultSlot :let={{ :info, as: :my_info }}>
      Info: {{ @my_info }}
    </OuterWithoutDefaultSlot>
    """

    message = """
    code:1: there's no `default` slot defined in `Surface.SlotTest.OuterWithoutDefaultSlot`.

    Directive :let can only be used on explicitly defined slots.

    Hint: You can define a `default` slot and its props using: \
    `slot default, props: [:info]\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end

  test "raise compile error when using :let with undefined props for default slot" do
    code = """
    <OuterWithDefaultSlotAndProps :let={{ :info, as: :my_info }} :let={{ :non_existing, as: :value }}>
      Info: {{ @my_info }}
    </OuterWithDefaultSlotAndProps>
    """

    message = """
    code:1: undefined prop `:non_existing` for slot `default` in \
    `Surface.SlotTest.OuterWithDefaultSlotAndProps`.

    Available props: [:info].

    Hint: You can define a new slot prop using the `props` option: \
    `slot default, props: [..., :non_existing]`\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end

  test "raise compile error when using :let with invalid binding" do
    code = """
    <OuterWithDefaultSlotAndProps
      :let={{ info: 1 }}>
      Info: {{ @my_info }}
    </OuterWithDefaultSlotAndProps>
    """

    message = """
    code:2: invalid value for directive :let. \
    Expected a mapping from a slot prop to an assign, \
    e.g. {{ :item }} or {{ :item, as: :user }}, got: {{ info: 1 }}.\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end

  test "raise compile error when using :let with undefined slot props" do
    code = """
    <OuterWithNamedSlotAndProps>
      <template slot="body" :let={{ :non_existing, as: :my_info }}>
        Info: {{ @my_info }}
      </template>
    </OuterWithNamedSlotAndProps>
    """

    message = """
    code:2: undefined prop `:non_existing` for slot `body` in \
    `Surface.SlotTest.OuterWithNamedSlotAndProps`.

    Available props: [:info].

    Hint: You can define a new slot prop using the `props` option: \
    `slot body, props: [..., :non_existing]`\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end
end

defmodule Surface.SlotSyncTest do
  use ExUnit.Case

  import ComponentTestHelper
  import ExUnit.CaptureIO

  alias Surface.SlotTest.OuterWithNamedSlot, warn: false
  alias Surface.SlotTest.InnerData, warn: false
  alias Surface.SlotTest.{Grid, Column}, warn: false
  alias Surface.SlotTest.StatefulComponent, warn: false

  test "warn if parent component does not define any slots" do
    code = """
    <StatefulComponent id="stateful">
      <InnerData/>
    </StatefulComponent>
    """

    output =
      capture_io(:standard_error, fn ->
        render_live(code)
      end)

    assert output =~ ~r"""
           no slot "inner" defined in parent component <StatefulComponent>
             code:2:\
           """
  end

  test "warn if parent component does not define the slot" do
    code = """
    <Grid items={{[]}}>
      <InnerData/>
      <Column title="ID"/>
    </Grid>
    """

    output =
      capture_io(:standard_error, fn ->
        render_live(code)
      end)

    assert output =~ ~r"""
           no slot "inner" defined in parent component <Grid>

             Available slot: "cols"
             code:2:\
           """
  end

  test "warn and suggest similar slot if parent component does not define the slot" do
    code = """
    <OuterWithNamedSlot>
      <template slot="foot">
        My footer
      </template>
    </OuterWithNamedSlot>
    """

    output =
      capture_io(:standard_error, fn ->
        render_live(code)
      end)

    assert output =~ ~r"""
           no slot "foot" defined in parent component <OuterWithNamedSlot>

             Did you mean "footer"\?

             Available slots: "footer", "header" and "default"
             code:2:\
           """
  end
end
