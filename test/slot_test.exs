defmodule Surface.SlotTest do
  use Surface.ConnCase, async: true

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

    prop label, :string
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

  defmodule OuterWithOptionalNamedSlot do
    use Surface.Component

    slot default
    slot header
    slot footer

    def render(assigns) do
      ~H"""
      <div>
        <header :if={{ slot_assigned?(:header) }}>
          <slot name="header"/>
        </header>
        <main :if={{ slot_assigned?(:default) }}>
          <slot>
            Default fallback
          </slot>
        </main>
        <footer>
        <slot name="footer">
          Footer fallback
        </slot>
        </footer>
      </div>
      """
    end
  end

  defmodule OuterWithRenamedSlot do
    use Surface.Component

    slot header, as: :default_header

    prop header, :string

    def render(assigns) do
      ~H"""
      <div>
        <slot name="header" />
        {{ @header }}
      </div>
      """
    end
  end

  defmodule OuterWithDefaultPropAndSlot do
    use Surface.Component

    slot default, as: :default_slot

    prop default, :string

    def render(assigns) do
      ~H"""
      <div>
        <slot />
        {{ @default }}
      </div>
      """
    end
  end

  defmodule Column do
    use Surface.Component, slot: "cols"

    prop title, :string, required: true

    def render(assigns), do: ~H()
  end

  defmodule ColumnWithDefaultTitle do
    use Surface.Component, slot: "cols"

    prop title, :string, default: "default title"

    def render(assigns), do: ~H()
  end

  defmodule Grid do
    use Surface.Component

    prop items, :list, required: true

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
    html =
      render_surface do
        ~H"""
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
      end

    assert_html(
      html =~ """
      <div>
        <div>
          label 1:<b>content 1</b>
          <div>Stateful</div>
        </div>
        <div>
          label 2:<b>content 2</b>
        </div>
        <div>
          Content 1
          Content 2
            Content 2.1
          Content 3
          <div>Stateful</div>
        </div>
      </div>
      """
    )
  end

  test "assign named slots with props" do
    html =
      render_surface do
        ~H"""
        <OuterWithNamedSlotAndProps>
          <template slot="body" :let={{ info: my_info }}>
            Info: {{ my_info }}
          </template>
        </OuterWithNamedSlotAndProps>
        """
      end

    assert_html(
      html =~ """
      <div>
        Info: Info from slot
      </div>
      """
    )
  end

  test "assign default slot with props" do
    html =
      render_surface do
        ~H"""
        <OuterWithDefaultSlotAndProps :let={{ info: my_info }}>
          Info: {{ my_info }}
        </OuterWithDefaultSlotAndProps>
        """
      end

    assert_html(
      html =~ """
      <div>
        Info: Info from slot
      </div>
      """
    )
  end

  test "assign default slot ignoring all props" do
    html =
      render_surface do
        ~H"""
        <OuterWithDefaultSlotAndProps>
          Info
        </OuterWithDefaultSlotAndProps>
        """
      end

    assert_html(
      html =~ """
      <div>
        Info
      </div>
      """
    )
  end

  test "assign named slots without props" do
    html =
      render_surface do
        ~H"""
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
      end

    assert_html(
      html =~ """
      <div>
        My header
        My body
        My footer
      </div>
      """
    )
  end

  test "assign undeclared slots without props" do
    html =
      render_surface do
        ~H"""
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
      end

    assert_html(
      html =~ """
      <div>
        My header
        My body
        My footer
      </div>
      """
    )
  end

  test "fallback content" do
    html =
      render_surface do
        ~H"""
        <OuterWithNamedSlot/>
        """
      end

    assert_html(
      html =~ """
      <div>
        Default fallback
        Footer fallback
      </div>
      """
    )
  end

  test "slotable component with default value for prop" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    html =
      render_surface do
        ~H"""
        <Grid items={{ user <- @items }}>
          <ColumnWithDefaultTitle>
            <b>Id: {{ user.id }}</b>
          </ColumnWithDefaultTitle>
        </Grid>
        """
      end

    assert_html(
      html =~ """
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

    html =
      render_surface do
        ~H"""
        <Grid items={{ user <- @items }}>
          <Column title="ID">
            <b>Id: {{ user.id }}</b>
          </Column>
          <Column title="NAME">
            Name: {{ user.name }}
          </Column>
        </Grid>
        """
      end

    assert_html(
      html =~ """
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

  test "rename slot with :as do not override other assigns with same name" do
    html =
      render_surface do
        ~H"""
        <OuterWithRenamedSlot header="My Header Prop">
          <template slot="header">
            My Header Slot
          </template>
        </OuterWithRenamedSlot>
        """
      end

    assert_html(
      html =~ """
      <div>
        My Header Slot
        My Header Prop
      </div>
      """
    )
  end

  test "default prop name with a default slot" do
    html =
      render_surface do
        ~H"""
        <OuterWithDefaultPropAndSlot default="Default Prop">
          Default Slot
        </OuterWithDefaultPropAndSlot>
        """
      end

    assert_html(
      html =~ """
      <div>
        Default Slot
        Default Prop
      </div>
      """
    )

    html =
      render_surface do
        ~H"""
        <OuterWithDefaultPropAndSlot default="Default Prop">
          <template name="default">
            Default Slot
          </template>
        </OuterWithDefaultPropAndSlot>
        """
      end

    assert_html(
      html =~ """
      <div>
        Default Slot
        Default Prop
      </div>
      """
    )
  end

  test "render slot renaming slot props" do
    assigns = %{items: [%{id: 1, name: "First"}]}

    html =
      render_surface do
        ~H"""
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
      end

    assert_html(
      html =~ """
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

    code =
      quote do
        ~H"""
        <Grid items={{ user <- @items }}>
          <Column title="ID"
            :let={{ item: my_user, non_existing: value }}>
            <b>Id: {{ my_user.id }}</b>
          </Column>
        </Grid>
        """
      end

    message = """
    code:3: undefined prop `:non_existing` for slot `cols` in `Surface.SlotTest.Grid`.

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

    code =
      quote do
        ~H"""
        <OuterWithNamedSlotAndProps>
          <template slot="body"
            :let={{ "a_string" }}>
          </template>
        </OuterWithNamedSlotAndProps>
        """
      end

    message = """
    code:3: invalid value for directive :let. \
    Expected a keyword list of bindings, \
    e.g. {{ item: user, info: info }}, got: {{ "a_string" }}.\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code, assigns)
    end)
  end

  test "raise compile error when using :let and there's no default slot defined" do
    code =
      quote do
        ~H"""
        <OuterWithoutDefaultSlot :let={{ info: my_info }}>
          Info: {{ my_info }}
        </OuterWithoutDefaultSlot>
        """
      end

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
    code =
      quote do
        ~H"""
        <OuterWithDefaultSlotAndProps :let={{ info: my_info, non_existing: value }}>
          Info: {{ my_info }}
        </OuterWithDefaultSlotAndProps>
        """
      end

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

  test "raise compile error when using :let with undefined slot props" do
    code =
      quote do
        ~H"""
        <OuterWithNamedSlotAndProps>
          <template slot="body" :let={{ non_existing: my_info }}>
            Info: {{ my_info }}
          </template>
        </OuterWithNamedSlotAndProps>
        """
      end

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

  test "raise compile error when passing invalid bindings to :let " do
    code =
      quote do
        ~H"""
        <OuterWithDefaultSlotAndProps
          :let={{ info: [my_info] }}>
          Info: {{ my_info }}
        </OuterWithDefaultSlotAndProps>
        """
      end

    message = """
    code:2: invalid value for directive :let. Expected a keyword list of bindings, \
    e.g. {{ item: user, info: info }}, got: {{ info: [my_info] }}.\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end

  test "raise compile error when passing an undefined prop to :props" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    code = """
    defmodule TestSlotPassingUndefinedProp_#{id} do
      use Surface.Component

      slot default, props: [:item]

      def render(assigns) do
        ~H"\""
          <span>
            <slot
              :props={{ id: 1, name: "Joe" }}/>
            </span>
        "\""
      end
    end
    """

    message = """
    code.exs:10: undefined props :id and :name for slot `default`.

    Defined prop: :item.

    Hint: You can define a new slot prop using the `props` option: \
    `slot default, props: [..., :some_prop]`\
    """

    assert_raise(CompileError, message, fn ->
      {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
    end)
  end

  test "does not render slot if slot_assigned? returns false" do
    assigns = %{}

    html =
      render_surface do
        ~H"""
        <OuterWithOptionalNamedSlot />
        """
      end

    assert_html(
      html =~ """
      <div>
        <footer>
          Footer fallback
        </footer>
      </div>
      """
    )

    html =
      render_surface do
        ~H"""
        <OuterWithOptionalNamedSlot>
          <template slot="header">
            My Header
          </template>
        </OuterWithOptionalNamedSlot>
        """
      end

    assert_html(
      html =~ """
      <div>
        <header>
          My Header
        </header>
        <footer>
          Footer fallback
        </footer>
      </div>
      """
    )

    html =
      render_surface do
        ~H"""
        <OuterWithOptionalNamedSlot>
          My Content
        </OuterWithOptionalNamedSlot>
        """
      end

    assert_html(
      html =~ """
      <div>
        <main>
          My Content
        </main>
        <footer>
          Footer fallback
        </footer>
      </div>
      """
    )
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
    code =
      quote do
        ~H"""
        <StatefulComponent id="stateful">
          <InnerData/>
        </StatefulComponent>
        """
      end

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
    code =
      quote do
        ~H"""
        <Grid items={{[]}}>
          <InnerData/>
          <Column title="ID"/>
        </Grid>
        """
      end

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
    code =
      quote do
        ~H"""
        <OuterWithNamedSlot>
          <div>
          </div>
          <template slot="foot">
            My footer
          </template>
        </OuterWithNamedSlot>
        """
      end

    output =
      capture_io(:standard_error, fn ->
        render_live(code)
      end)

    assert output =~ ~r"""
           no slot "foot" defined in parent component <OuterWithNamedSlot>

             Did you mean "footer"\?

             Available slots: "footer", "header" and "default"
             code:4:\
           """
  end

  test "warn on component that uses slot_assigned?/1 with a non existing slot" do
    component_code = """
    defmodule TestComponentWithWrongOptionalSlotName do
      use Surface.Component

      slot header
      slot default
      slot footer

      def render(assigns) do
        ~H"\""
          <div>
            <header :if={{ slot_assigned?(:heade) }}>
              <slot name="header"/>
            </header>
            <slot />
            <footer>
              <slot name="footer" />
            </footer>
          </div>
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(component_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           no slot "heade" defined in the component 'Elixir.Surface.SlotSyncTest.TestComponentWithWrongOptionalSlotName'

             Did you mean "header"\?

             Available slots: "default", "footer" and "header"
             code.exs:11:\
           """
  end
end
