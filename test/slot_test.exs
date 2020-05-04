defmodule SlotTest do
  use ExUnit.Case
  use Phoenix.ConnTest
  import ComponentTestHelper
  import ExUnit.CaptureIO

  defmodule StatefulComponent do
    use Surface.LiveComponent

    def render(assigns) do
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
      ~H"""
      <div>
        <div :for={{ data <- @inner }}>
          {{ data.label }}: {{ data.inner_content.([]) }}
        </div>
        <div>
          {{ @inner_content.([]) }}
        </div>
      </div>
      """
    end
  end

  defmodule OuterWithSlotNotation do
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

  defmodule OuterWithSlotNotationWithoutDeclaring do
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

  defmodule OuterWithSlotNotationAndProps do
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

  defmodule OuterWithSlotNotationDefaultAndProps do
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
    code = """
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

    assert_html(
      render_live(code) =~ """
      <div>
        <div>
          label 1:<b>content 1</b>
          <div data-phx-component="0">Stateful</div>
        </div>
        <div>
          label 2:<b>content 2</b>
        </div>
        <div>
          Content 1
          Content 2
            Content 2.1
          Content 3
          <div data-phx-component="1">Stateful</div>
        </div>
      </div>
      """
    )
  end

  test "assign slots with props using <slot/> notation" do
    code = """
    <OuterWithSlotNotationAndProps>
      <template slot="body" :let={{ info: my_info }}>
        Info: {{ my_info }}
      </template>
    </OuterWithSlotNotationAndProps>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        Info: Info from slot
      </div>
      """
    )
  end

  test "assign default slot with props using <slot/> notation" do
    code = """
    <OuterWithSlotNotationDefaultAndProps :let={{ info: my_info }}>
      Info: {{ my_info }}
    </OuterWithSlotNotationDefaultAndProps>
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
    <OuterWithSlotNotationDefaultAndProps>
      Info
    </OuterWithSlotNotationDefaultAndProps>
    """

    assert_html(
      render_live(code) =~ """
      <div>
        Info
      </div>
      """
    )
  end

  test "assign slots without props using <slot/> notation" do
    code = """
    <OuterWithSlotNotation>
      <template slot="header">
        My header
      </template>
      My body
      <template slot="footer">
        My footer
      </template>
    </OuterWithSlotNotation>
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

  test "assign undeclared slots without props using <slot/> notation" do
    code = """
    <OuterWithSlotNotationWithoutDeclaring>
      <template slot="header">
        My header
      </template>
      My body
      <template slot="footer">
        My footer
      </template>
    </OuterWithSlotNotationWithoutDeclaring>
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

  test "fallback content using <slot/> notation" do
    code = """
    <OuterWithSlotNotation/>
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

  test "render inner content with slot props containing parent bindings" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    code = """
    <Grid items={{ user <- @items }}>
      <Column title="ID">
        <b>Id: {{ user.id }}</b>
      </Column>
      <Column title="NAME">
        Name: {{ user.name }}
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

  test "render inner content renaming slot props" do
    assigns = %{items: [%{id: 1, name: "First"}]}

    code = """
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
      <Column title="ID" :let={{ item: my_user, non_existing: 1}}>
        <b>Id: {{ my_user.id }}</b>
      </Column>
    </Grid>
    """

    message = """
    code:2: undefined prop `:non_existing` for slot `cols` in `SlotTest.Column`.

    Available props: [:item, :info].

    Hint: You can define a new slot prop using the `props` option: \
    `slot cols, props: [..., :non_existing]`\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code, assigns)
    end)
  end

  test "render default inner_content with slot props" do
    code = """
    <OuterWithDefaultSlotAndProps :let={{ info: my_info }}>
      Info: {{ my_info }}
    </OuterWithDefaultSlotAndProps>
    """

    assert_html(
      render_live(code) == """
      <div>
        Info: Info from slot
      </div>
      """
    )
  end

  test "raise compile error when using :let and there's no default slot defined" do
    code = """
    <OuterWithoutDefaultSlot :let={{ info: my_info }}>
      Info: {{ my_info }}
    </OuterWithoutDefaultSlot>
    """

    message = """
    code:1: there's no `default` slot defined in `SlotTest.OuterWithoutDefaultSlot`.

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
    <OuterWithDefaultSlotAndProps :let={{ info: my_info, non_existing: 1 }}>
      Info: {{ my_info }}
    </OuterWithDefaultSlotAndProps>
    """

    message = """
    code:1: undefined prop `:non_existing` for slot `default` in \
    `SlotTest.OuterWithDefaultSlotAndProps`.

    Available props: [:info].

    Hint: You can define a new slot prop using the `props` option: \
    `slot default, props: [..., :non_existing]`\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end

  test "raise compile error when using :let with undefined slot props" do
    code = """
    <OuterWithSlotNotationAndProps>
      <template slot="body" :let={{ non_existing: my_info }}>
        Info: {{ my_info }}
      </template>
    </OuterWithSlotNotationAndProps>
    """

    message = """
    code:2: undefined prop `:non_existing` for slot `body` in \
    `SlotTest.OuterWithSlotNotationAndProps`.

    Available props: [:info].

    Hint: You can define a new slot prop using the `props` option: \
    `slot body, props: [..., :non_existing]`\
    """

    assert_raise(CompileError, message, fn ->
      render_live(code)
    end)
  end

  test "warn if parent component does not define any slots" do
    code = """
    <StatefulComponent>
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
    <OuterWithSlotNotation>
      <template slot="foot">
        My footer
      </template>
    </OuterWithSlotNotation>
    """

    output =
      capture_io(:standard_error, fn ->
        render_live(code)
      end)

    assert output =~ ~r"""
           no slot "foot" defined in parent component <OuterWithSlotNotation>

             Did you mean "footer"\?

             Available slots: "footer", "header" and "default"
             code:2:\
           """
  end
end
