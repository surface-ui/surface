defmodule Surface.SlotTest do
  use Surface.ConnCase, async: true

  defmodule StatefulComponent do
    use Surface.LiveComponent

    def render(assigns) do
      ~F"""
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
      ~F"""
      <div>
        <div :for={data <- @inner}>
          {data.label}: <#slot {data} />
        </div>
        <div>
          <#slot />
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
      ~F"""
      <div>
        <#slot {@header}/>
        <#slot>
          Default fallback
        </#slot>
        <#slot {@footer}>
          Footer fallback
        </#slot>
      </div>
      """
    end
  end

  defmodule OuterWithNamedSlotAndArg do
    use Surface.Component

    slot body, arg: %{info: :string}

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@body, info: "Info from slot"} />
      </div>
      """
    end
  end

  defmodule OuterWithDefaultSlotAndArg do
    use Surface.Component

    slot default, arg: %{info: :string}

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@default, info: "Info from slot"}/>
      </div>
      """
    end
  end

  defmodule OuterWithDefaultSlotAndStringArg do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@default, "Info from slot"} />
      </div>
      """
    end
  end

  defmodule OuterWithDefaultSlotAndKeywordArg do
    use Surface.Component

    slot default, arg: :keyword

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@default, [name: "Jane", name: "Joe"]}/>
      </div>
      """
    end
  end

  defmodule OuterWithDefaultSlotAndArgFromGenerator do
    use Surface.Component

    prop items, :generator, required: true
    slot default, generator_prop: :items

    def render(assigns) do
      ~F"""
      <div>
        {#for item <- @items}
          <#slot generator_value={item}/>
        {/for}
      </div>
      """
    end
  end

  defmodule OuterWithoutDefaultSlot do
    use Surface.Component

    def render(assigns) do
      ~F"""
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
      ~F"""
      <div>
        <header :if={slot_assigned?(@header)}>
          <#slot {@header}/>
        </header>
        <main :if={slot_assigned?(:default)}>
          <#slot>
            Default fallback
          </#slot>
        </main>
        <footer>
        <#slot {@footer}>
          Footer fallback
        </#slot>
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
      ~F"""
      <div>
        <#slot {@default_header} />
        {@header}
      </div>
      """
    end
  end

  defmodule OuterWithDefaultPropAndSlot do
    use Surface.Component

    slot default, as: :default_slot

    prop default, :string

    def render(assigns) do
      ~F"""
      <div>
        <#slot />
        {@default}
      </div>
      """
    end
  end

  defmodule Column do
    use Surface.Component, slot: "col"

    prop title, :string, required: true
  end

  defmodule ColumnWithDefaultTitle do
    use Surface.Component, slot: "col"

    prop title, :string, default: "default title"
  end

  defmodule ColumnWithRender do
    use Surface.Component, slot: "col"

    prop title, :string, required: true

    slot default

    def render(assigns) do
      ~F"""
      <span class="fancy-column">
        <#slot>
          {@title}
        </#slot>
      </span>
      """
    end
  end

  defmodule ColumnWithRenderAndDefaultTitle do
    use Surface.Component, slot: "col"

    prop title, :string, default: "default title"

    slot default

    def render(assigns) do
      ~F"""
      <span class="fancy-column">
        <#slot>
          {@title}
        </#slot>
      </span>
      """
    end
  end

  defmodule Grid do
    use Surface.Component

    prop items, :generator, required: true

    slot col, as: :cols, arg: %{info: :string}, generator_prop: :items

    def render(assigns) do
      ~F"""
      <table>
        <tr>
          <th :for={col <- @cols}>
            {col.title}
          </th>
        </tr>
        <tr :for={item <- @items}>
          <td :for={col <- @cols}>
            <#slot {col, info: "Some info from Grid"} generator_value={item} />
          </td>
        </tr>
      </table>
      """
    end
  end

  test "render slot without slot arg" do
    html =
      render_surface do
        ~F"""
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

    assert html =~ """
           <div>
             <div>
               label 1: \

               <b>content 1</b>
               <div>Stateful</div>
             </div><div>
               label 2: \

               <b>content 2</b>
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
  end

  test "render Slotable and named slot with numbers" do
    html =
      render_surface do
        ~F"""
        <OuterWithMultipleSlotableEntries>
          <InnerData label={1000} />
          <:inner label={1001} />
        </OuterWithMultipleSlotableEntries>
        """
      end

    assert html =~ """
           <div>
             <div>
               1000: \

             </div><div>
               1001: \

             </div>
             <div>
             </div>
           </div>
           """
  end

  test "render multiple slot entries with props (shorthand notation)" do
    html =
      render_surface do
        ~F"""
        <OuterWithMultipleSlotableEntries>
          Content 1
          <:inner label="label 1">
            <b>content 1</b>
            <StatefulComponent id="stateful1"/>
          </:inner>
          Content 2
            Content 2.1
          <:inner label="label 2">
            <b>content 2</b>
          </:inner>
          Content 3
          <StatefulComponent id="stateful2"/>
        </OuterWithMultipleSlotableEntries>
        """
      end

    assert html =~ """
           <div>
             <div>
               label 1: \

               <b>content 1</b>
               <div>Stateful</div>
             </div><div>
               label 2: \

               <b>content 2</b>
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
  end

  test "assign named slots with arg" do
    html =
      render_surface do
        ~F"""
        <OuterWithNamedSlotAndArg>
          <:body :let={info: my_info}>
            Info: {my_info}
          </:body>
        </OuterWithNamedSlotAndArg>
        """
      end

    assert html =~ """
           <div>
               Info: Info from slot
           </div>
           """
  end

  test "raises if arg doesn't match :let" do
    assert_raise_with_line(
      ArgumentError,
      "cannot match slot argument against :let. Expected a value matching `%{info: my_info, b: b}`, got: %{info: \"Info from slot\"}.",
      4,
      fn ->
        render_surface do
          ~F"""
          <OuterWithDefaultSlotAndArg
            :let={%{info: my_info, b: b}}>
            {my_info}{b}
          </OuterWithDefaultSlotAndArg>
          """
        end
      end
    )
  end

  test "raise runtime error when using :let without slot arg" do
    assert_raise(
      ArgumentError,
      "cannot match slot argument against :let. Expected a value matching `[wrong]`, got: nil.",
      fn ->
        render_surface do
          ~F"""
          <OuterWithNamedSlot :let={[wrong]}>
            {wrong}
          </OuterWithNamedSlot>
          """
        end
      end
    )
  end

  test "assign default slot with arg" do
    html =
      render_surface do
        ~F"""
        <OuterWithDefaultSlotAndArg :let={info: my_info}>
          Info: {my_info}
        </OuterWithDefaultSlotAndArg>
        """
      end

    assert html =~ """
           <div>
             Info: Info from slot
           </div>
           """
  end

  test "assign default slot with string arg" do
    html =
      render_surface do
        ~F"""
        <OuterWithDefaultSlotAndStringArg :let={my_info}>
          Info: {my_info}
        </OuterWithDefaultSlotAndStringArg>
        """
      end

    assert html =~ """
           <div>
             Info: Info from slot
           </div>
           """
  end

  test "assign default slot with keyword arg" do
    html =
      render_surface do
        ~F"""
        <OuterWithDefaultSlotAndKeywordArg :let={[name: name1, name: name2]}>
          Name 1: {name1}
          Name 2: {name2}
        </OuterWithDefaultSlotAndKeywordArg>
        """
      end

    assert html =~ """
           <div>
             Name 1: Jane
             Name 2: Joe
           </div>
           """
  end

  test "assign default slot ignoring all arg" do
    html =
      render_surface do
        ~F"""
        <OuterWithDefaultSlotAndArg>
          Info
        </OuterWithDefaultSlotAndArg>
        """
      end

    assert html =~ """
           <div>
             Info
           </div>
           """
  end

  test "assign default slot with arg from generator" do
    html =
      render_surface do
        ~F"""
        <OuterWithDefaultSlotAndArgFromGenerator items={i <- [1, 2]}>
          Item: {i}
        </OuterWithDefaultSlotAndArgFromGenerator>
        """
      end

    assert html =~ """
           <div>
             Item: 1
             Item: 2
           </div>
           """
  end

  test "assign named slots without arg" do
    html =
      render_surface do
        ~F"""
        <OuterWithNamedSlot>
          <:header>
            My header
          </:header>
          My body
          <:footer>
            My footer
          </:footer>
        </OuterWithNamedSlot>
        """
      end

    assert html =~ """
           <div>
               My header
             My body
               My footer
           </div>
           """
  end

  test "fallback content" do
    html =
      render_surface do
        ~F"""
        <OuterWithNamedSlot/>
        """
      end

    assert html =~ """
           <div>
               Default fallback
               Footer fallback
           </div>
           """
  end

  test "slotable component with default value for arg" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    html =
      render_surface do
        ~F"""
        <Grid items={user <- @items}>
          <ColumnWithDefaultTitle>
            <b>Id: {user.id}</b>
          </ColumnWithDefaultTitle>
        </Grid>
        """
      end

    assert html =~ """
           <table>
             <tr>
               <th>
                 default title
               </th>
             </tr>
             <tr>
               <td>
               <b>Id: 1</b>
               </td>
             </tr><tr>
               <td>
               <b>Id: 2</b>
               </td>
             </tr>
           </table>
           """
  end

  test "slotable component with render defined" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    html =
      render_surface do
        ~F"""
        <Grid items={user <- @items}>
          <ColumnWithRender title="column title">
            <b>Id: {user.id}</b>
          </ColumnWithRender>
        </Grid>
        """
      end

    assert html =~ """
           <table>
             <tr>
               <th>
                 column title
               </th>
             </tr>
             <tr>
               <td>
                 <span class="fancy-column">
               <b>Id: 1</b>
           </span>
               </td>
             </tr><tr>
               <td>
                 <span class="fancy-column">
               <b>Id: 2</b>
           </span>
               </td>
             </tr>
           </table>
           """
  end

  test "slotable component with render defined with no content" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    html =
      render_surface do
        ~F"""
        <Grid items={_user <- @items}>
          <ColumnWithRenderAndDefaultTitle />
        </Grid>
        """
      end

    assert html =~ """
           <table>
             <tr>
               <th>
                 default title
               </th>
             </tr>
             <tr>
               <td>
                 <span class="fancy-column">
               default title
           </span>
               </td>
             </tr><tr>
               <td>
                 <span class="fancy-column">
               default title
           </span>
               </td>
             </tr>
           </table>
           """
  end

  test "render slot with slot arg containing parent bindings" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    html =
      render_surface do
        ~F"""
        <Grid items={user <- @items}>
          <Column title="ID">
            <b>Id: {user.id}</b>
          </Column>
          <Column title="NAME">
            Name: {user.name}
          </Column>
        </Grid>
        """
      end

    assert html =~ """
           <table>
             <tr>
               <th>
                 ID
               </th><th>
                 NAME
               </th>
             </tr>
             <tr>
               <td>
               <b>Id: 1</b>
               </td><td>
               Name: First
               </td>
             </tr><tr>
               <td>
               <b>Id: 2</b>
               </td><td>
               Name: Second
               </td>
             </tr>
           </table>
           """
  end

  test "render slot with slot arg containing parent bindings (shorthand notation)" do
    assigns = %{items: [%{id: 1, name: "First"}, %{id: 2, name: "Second"}]}

    html =
      render_surface do
        ~F"""
        <Grid items={user <- @items}>
          <:col title="ID">
            <b>Id: {user.id}</b>
          </:col>
          <:col title="NAME">
            Name: {user.name}
          </:col>
        </Grid>
        """
      end

    assert html =~ """
           <table>
             <tr>
               <th>
                 ID
               </th><th>
                 NAME
               </th>
             </tr>
             <tr>
               <td>
               <b>Id: 1</b>
               </td><td>
               Name: First
               </td>
             </tr><tr>
               <td>
               <b>Id: 2</b>
               </td><td>
               Name: Second
               </td>
             </tr>
           </table>
           """
  end

  test "raises if reusing generator variable names in :let" do
    code =
      quote do
        ~F"""
        <Grid items={{i, j} <- @items}>
          <Column title="ID" :let={info: [i, j]} />
        </Grid>
        """
      end

    message = ~r"""
    code:2:
    #{maybe_ansi("error:")} cannot use :let to redefine variable from the component's generator\.

    variables `i` and `j` already defined in `{i, j} <- @items` at code:1

    Hint: choose a different name.\
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "rename slot with :as do not override other assigns with same name" do
    html =
      render_surface do
        ~F"""
        <OuterWithRenamedSlot header="My Header Prop">
          <:header>
            My Header Slot
          </:header>
        </OuterWithRenamedSlot>
        """
      end

    assert html =~ """
           <div>
               My Header Slot
             My Header Prop
           </div>
           """
  end

  test "default prop name with a default slot" do
    html =
      render_surface do
        ~F"""
        <OuterWithDefaultPropAndSlot default="Default Prop">
          Default Slot
        </OuterWithDefaultPropAndSlot>
        """
      end

    assert html =~ """
           <div>
             Default Slot
             Default Prop
           </div>
           """

    html =
      render_surface do
        ~F"""
        <OuterWithDefaultPropAndSlot default="Default Prop">
          <:default>
            Default Slot
          </:default>
        </OuterWithDefaultPropAndSlot>
        """
      end

    assert html =~ """
           <div>
               Default Slot
             Default Prop
           </div>
           """
  end

  defmodule PhoenixComponentWithSlots do
    use Phoenix.Component

    def my_component(assigns) do
      assigns =
        assigns
        |> assign_new(:header, fn -> [] end)
        |> assign_new(:footer, fn -> [] end)

      ~H"""
      <div>
        Header: <%= render_slot(@header) %>
        Default: <%= render_slot(@inner_block) %>
        Footer: <%= render_slot(@footer) %>
      </div>
      """
    end

    def my_component_with_arg(assigns) do
      assigns =
        assigns
        |> assign_new(:header, fn -> [] end)
        |> assign_new(:footer, fn -> [] end)

      ~H"""
      <div>
        Header: <%= render_slot(@header, "header_arg") %>
        Default: <%= render_slot(@inner_block, "default_arg") %>
        Footer: <%= render_slot(@footer, "footer_arg") %>
      </div>
      """
    end
  end

  test "render vanilla phoenix components with slots" do
    html =
      render_surface do
        ~F"""
        <PhoenixComponentWithSlots.my_component>
          <:header>header</:header>
          <p>default</p>
          <:footer>footer</:footer>
        </PhoenixComponentWithSlots.my_component>
        """
      end

    assert html =~ """
           <div>
             Header: header
             Default: \

             <p>default</p>
             Footer: footer
           </div>
           """
  end

  test "render vanilla phoenix components with slots and arg" do
    html =
      render_surface do
        ~F"""
        <PhoenixComponentWithSlots.my_component_with_arg :let={default_arg}>
          <:header :let={header_arg}>header ({header_arg})</:header>
          <p>default ({default_arg})</p>
          <:footer :let={footer_arg}>footer ({footer_arg})</:footer>
        </PhoenixComponentWithSlots.my_component_with_arg>
        """
      end

    assert html =~ """
           <div>
             Header: header (header_arg)
             Default: \

             <p>default (default_arg)</p>
             Footer: footer (footer_arg)
           </div>
           """
  end

  test "render vanilla phoenix components with slots and arg2" do
    assert_raise_with_line(
      ArgumentError,
      "cannot match slot argument against :let. Expected a value matching [wrong], got: `\"default_arg\"`.",
      4,
      fn ->
        render_surface do
          ~F"""
          <PhoenixComponentWithSlots.my_component_with_arg
            :let={[wrong]}>
            <p>{wrong}</p>
          </PhoenixComponentWithSlots.my_component_with_arg>
          """
        end
      end
    )
  end

  test "render slot renaming slot arg" do
    assigns = %{items: [%{id: 1, name: "First"}]}

    html =
      render_surface do
        ~F"""
        <Grid items={user <- @items}>
          <Column title="ID">
            <b>Id: {user.id}</b>
          </Column>
          <Column title="NAME" :let={info: my_info}>
            Name: {user.name}
            Info: {my_info}
          </Column>
        </Grid>
        """
      end

    assert html =~ """
           <table>
             <tr>
               <th>
                 ID
               </th><th>
                 NAME
               </th>
             </tr>
             <tr>
               <td>
               <b>Id: 1</b>
               </td><td>
               Name: First
               Info: Some info from Grid
               </td>
             </tr>
           </table>
           """
  end

  test "raise compile error for invalid :let pattern (multiple clauses)" do
    assigns = %{items: [%{id: 1, name: "First"}]}

    code =
      quote do
        ~F"""
        <OuterWithNamedSlotAndArg>
          <:body
            :let={"a_string", "other_string"}>
          </:body>
        </OuterWithNamedSlotAndArg>
        """
      end

    message = ~r"""
    code:3:
    #{maybe_ansi("error:")} invalid value for directive :let\. \
    Expected a pattern to be matched by the slot argument, \
    got: {"a_string", "other_string"}\.\
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code, assigns)
    end)
  end

  test "raise compile error when using :let and there's no default slot defined" do
    code =
      quote do
        ~F"""
        <OuterWithoutDefaultSlot :let={info: my_info}>
          Info: {my_info}
        </OuterWithoutDefaultSlot>
        """
      end

    message = ~r"""
    code:1:
    #{maybe_ansi("error:")} no slot "default" defined in parent component <OuterWithoutDefaultSlot>
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raise compile error for invalid :let pattern (clause and opts)" do
    code =
      quote do
        ~F"""
        <OuterWithDefaultSlotAndArg
          :let={a, info: [my_info]}>
          A: {a}
          Info: {my_info}
        </OuterWithDefaultSlotAndArg>
        """
      end

    message = ~r"""
    code:2:
    #{maybe_ansi("error:")} invalid value for directive :let\. \
    Expected a pattern to be matched by the slot argument, \
    got: {a, info: \[my_info\]}\.\
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raise compile error for invalid arg expression (multiple clauses)" do
    code =
      quote do
        ~F"""
          <#slot
            {@default, a, b} />
        """
      end

    message = ~r"""
    code:2:
    #{maybe_ansi("error:")} invalid value for attribute "root"\. \
    Expected the slot and a single expression to be given as the slot argument, \
    got: {@default, a, b}\.\
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raise compile error for invalid arg expression (clause and opts)" do
    code =
      quote do
        ~F"""
          <#slot
            {@default, a, info: "Info from slot"} />
        """
      end

    message = ~r"""
    code:2:
    #{maybe_ansi("error:")} invalid value for attribute "root"\. \
    Expected the slot and a single expression to be given as the slot argument, \
    got: {@default, a, info: "Info from slot"}\.\
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "does not render slot if slot_assigned? returns false" do
    assigns = %{}

    html =
      render_surface do
        ~F"""
        <OuterWithOptionalNamedSlot/>
        """
      end

    assert html =~ """
           <div>
             <footer>
               Footer fallback
             </footer>
           </div>
           """

    html =
      render_surface do
        ~F"""
        <OuterWithOptionalNamedSlot>
          <:header>
            My Header
          </:header>
        </OuterWithOptionalNamedSlot>
        """
      end

    assert html =~ """
           <div>
             <header>
               My Header
             </header>
             <footer>
               Footer fallback
             </footer>
           </div>
           """

    html =
      render_surface do
        ~F"""
        <OuterWithOptionalNamedSlot>
          My Content
        </OuterWithOptionalNamedSlot>
        """
      end

    assert html =~ """
           <div>
             <main>
             My Content
             </main>
             <footer>
               Footer fallback
             </footer>
           </div>
           """
  end

  describe "Shorthand notatation for assigning slots" do
    test "assign named slots without arg" do
      html =
        render_surface do
          ~F"""
          <OuterWithNamedSlot>
            <:header>
              My header
            </:header>
            My body
            <:footer>
              My footer
            </:footer>
          </OuterWithNamedSlot>
          """
        end

      assert html =~ """
             <div>
                 My header
               My body
                 My footer
             </div>
             """
    end

    test "does not render slot if slot_assigned? returns false" do
      html =
        render_surface do
          ~F"""
          <OuterWithOptionalNamedSlot>
            <:header>
              My Header
            </:header>
          </OuterWithOptionalNamedSlot>
          """
        end

      assert html =~ """
             <div>
               <header>
                 My Header
               </header>
               <footer>
                 Footer fallback
               </footer>
             </div>
             """
    end

    test "assign named slots with arg" do
      html =
        render_surface do
          ~F"""
          <OuterWithNamedSlotAndArg>
            <:body :let={info: my_info}>
              Info: {my_info}
            </:body>
          </OuterWithNamedSlotAndArg>
          """
        end

      assert html =~ """
             <div>
                 Info: Info from slot
             </div>
             """
    end
  end
end

defmodule Surface.SlotSyncTest do
  use Surface.ConnCase

  import ExUnit.CaptureIO

  alias Surface.SlotTest.OuterWithoutDefaultSlot, warn: false
  alias Surface.SlotTest.OuterWithNamedSlotAndArg, warn: false
  alias Surface.SlotTest.OuterWithNamedSlot, warn: false
  alias Surface.SlotTest.InnerData, warn: false
  alias Surface.SlotTest.{Grid, Column}, warn: false
  alias Surface.SlotTest.StatefulComponent, warn: false

  test "raises compile error if parent component does not define any slots" do
    code =
      quote do
        ~F"""
        <StatefulComponent id="stateful">
          <InnerData/>
        </StatefulComponent>
        """
      end

    message = ~r"""
    code:2:
    #{maybe_ansi("error:")} The slotable component <Surface.SlotTest.InnerData> has the `:slot` option set to `inner`\.

    That slot name is not declared in parent component <StatefulComponent>\.

    Please declare the slot in the parent component or rename the value in the `:slot` option\.
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raise compile error if parent component does not define the slot" do
    code =
      quote do
        ~F"""
        <Grid items={[]}>
          <InnerData/>
          <Column title="ID"/>
        </Grid>
        """
      end

    message = ~r"""
    code:2:
    #{maybe_ansi("error:")} The slotable component <Surface.SlotTest.InnerData> has the `:slot` option set to `inner`\.

    That slot name is not declared in parent component <Grid>\.

    Please declare the slot in the parent component or rename the value in the `:slot` option\.

    Available slot: "col"
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raise compile error and suggest similar slot if parent component does not define the slot" do
    code =
      quote do
        ~F"""
        <OuterWithNamedSlot>
          <div>
          </div>
          <:foot>
            My footer
          </:foot>
        </OuterWithNamedSlot>
        """
      end

    message = ~r"""
    code:4:
    #{maybe_ansi("error:")} no slot "foot" defined in parent component <OuterWithNamedSlot>

    Did you mean "footer"\?

    Available slots: "default", "header" and "footer"
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "raises compile error on component that uses undeclared slots" do
    component_code = """
    defmodule TestComponentWithoutDeclaringSlots do
      use Surface.Component

      slot header
      slot default

      def render(assigns) do
        ~F"\""
          <div>
            <#slot {@header}/>
            <#slot />
            <#slot {@footer} />
          </div>
        "\""
      end
    end
    """

    message = ~r"""
    code:12:
    #{maybe_ansi("error:")} no slot `footer` defined in the component `Surface.SlotSyncTest.TestComponentWithoutDeclaringSlots`

    Available slots: "default" and "header"\

    Hint: You can define slots using the `slot` macro\.\

    For instance: `slot footer`\
    """

    assert_raise(Surface.CompileError, message, fn ->
      capture_io(:standard_error, fn ->
        Code.eval_string(component_code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end)
  end

  test "raises compile error on component that uses short syntax <#slot /> without declaring default slot" do
    component_code = """
    defmodule TestComponentWithShortSyntaxButWithoutDeclaringDefaultSlot do
      use Surface.Component

      def render(assigns) do
        ~F"\""
          <div>
            <#slot />
          </div>
        "\""
      end
    end
    """

    message = ~r"""
    code:7:
    #{maybe_ansi("error:")} no slot `default` defined in the component `Surface.SlotSyncTest.TestComponentWithShortSyntaxButWithoutDeclaringDefaultSlot`

    Please declare the default slot using `slot default` in order to use the `<#slot />` notation\.
    """

    assert_raise(Surface.CompileError, message, fn ->
      capture_io(:standard_error, fn ->
        Code.eval_string(component_code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end)
  end

  test "warn on component that uses slot_assigned?/1 with a non existing slot" do
    component_code = """
    defmodule TestComponentWithWrongOptionalSlotName do
      use Surface.Component

      slot header
      slot default
      slot footer

      def render(assigns) do
        ~F"\""
          <div>
            <header :if={slot_assigned?(:heade)}>
              <#slot {@header}/>
            </header>
            <#slot />
            <footer>
              <#slot {@footer} />
            </footer>
          </div>
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(component_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           no slot "heade" defined in the component 'Elixir.Surface.SlotSyncTest.TestComponentWithWrongOptionalSlotName'

             Did you mean "header"\?

             Available slots: "default", "footer" and "header"
             code.exs:11:\
           """
  end

  test "warn on component that uses slot_assigned?(@var) when @var does not exist" do
    component_code = """
    defmodule TestComponentWithWrongOptionalSlotName do
      use Surface.Component

      slot header
      slot default
      slot footer

      def render(assigns) do
        ~F"\""
          <div>
            <header :if={slot_assigned?(@heade)}>
              <#slot {@header}/>
            </header>
            <#slot />
            <footer>
              <#slot {@footer} />
            </footer>
          </div>
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(component_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           no slot "heade" defined in the component 'Elixir.Surface.SlotSyncTest.TestComponentWithWrongOptionalSlotName'

             Did you mean "header"\?

             Available slots: "default", "footer" and "header"
             code.exs:11:\
           """
  end

  test "raise compile error when using :let and there's no default slot defined" do
    code =
      quote do
        ~F"""
        <OuterWithoutDefaultSlot :let={info: my_info}>
          Info: {my_info}
        </OuterWithoutDefaultSlot>
        """
      end

    message = ~r"""
    code:1:
    #{maybe_ansi("error:")} no slot "default" defined in parent component <OuterWithoutDefaultSlot>
    """

    assert_raise(Surface.CompileError, message, fn ->
      compile_surface(code)
    end)
  end

  test "unused generator bindings don't emit warnings" do
    code =
      quote do
        ~F"""
        <Grid items={%{name: name} = user <- @items}>
          <Column title="ID">
            <b>Id: {user.id}</b>
          </Column>
          <Column title="NAME">
            Name: {name}
          </Column>
        </Grid>
        """
      end

    assert "" == capture_io(:standard_error, fn -> compile_surface(code) end)
  end

  test "function components with :let that always match don't emit warnings" do
    code =
      quote do
        ~F"""
        <Surface.SlotTest.PhoenixComponentWithSlots.my_component_with_arg :let={default_arg}>
          {default_arg}
        </Surface.SlotTest.PhoenixComponentWithSlots.my_component_with_arg>
        """
      end

    output = capture_io(:standard_error, fn -> compile_surface(code) end)

    refute output =~ """
           this clause cannot match because a previous clause at line 1 always matches
             code:1
           """

    assert output == ""
  end

  test "raise on invalid attrs/directives" do
    code = """
    defmodule ComponentWithInvalidDirective do
      use Surface.Component

      slot default

      def render(assigns) do
        ~F"\""
        <br>
        <#slot
          :attrs={info: "info"}/>
        "\""
      end
    end
    """

    message = ~r"""
    code:10:
    #{maybe_ansi("error:")} invalid directive `:attrs` for <#slot>\.

    Slots only accept the root prop, `generator_value`, `:if` and `:for`\.
    """

    assert_raise(Surface.CompileError, message, fn ->
      capture_io(:standard_error, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end)

    code = """
    defmodule ComponentWithInvalidAttr do
      use Surface.Component

      slot default

      def render(assigns) do
        ~F"\""
        <br>
        <#slot
          {@default}
          let={info: info}
          :show={true}
          />
        "\""
      end
    end
    """

    message = ~r"""
    code:11:
    #{maybe_ansi("error:")} invalid attribute `let` for <#slot>\.

    Slots only accept the root prop, `generator_value`, `:if` and `:for`\.
    """

    assert_raise(Surface.CompileError, message, fn ->
      capture_io(:standard_error, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end)
  end

  test "raise on passing dynamic attributes" do
    code = """
    defmodule ComponentWithDynamicAttrs do
      use Surface.Component

      slot default

      def render(assigns) do
        ~F"\""
        <br>
        <#slot
          {...@attrs}/>
        "\""
      end
    end
    """

    message = ~r"""
    code:10:
    #{maybe_ansi("error:")} cannot pass dynamic attributes to <#slot>.

    Slots only accept the root prop, `for`, `name`, `index`, `generator_value`, `:if` and `:for`.
    """

    assert_raise(Surface.CompileError, message, fn ->
      capture_io(:standard_error, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end)
  end

  test "raise on passing asd" do
    code = """
    defmodule ComponentWithDynamicAttrs do
      use Surface.Component

      slot default

      def render(assigns) do
        ~F"\""
        <br>
        <#slot
          {...@attrs}/>
        "\""
      end
    end
    """

    message = ~r"""
    code:10:
    #{maybe_ansi("error:")} cannot pass dynamic attributes to <#slot>.

    Slots only accept the root prop, `for`, `name`, `index`, `generator_value`, `:if` and `:for`.
    """

    assert_raise(Surface.CompileError, message, fn ->
      capture_io(:standard_error, fn ->
        Code.eval_string(code, [], %{__ENV__ | file: "code", line: 1})
      end)
    end)
  end

  test "outputs compile warning when adding arg attribute to the default slot in a slotable component" do
    component_code = """
    defmodule ColumnWithRenderAndSlotArg do
      use Surface.Component, slot: "cols"

      prop title, :string, required: true

      slot default

      def render(assigns) do
        ~F"\""
        <span class="fancy-column">
          <#slot {@default, info: "this is a test"} />
        </span>
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(component_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ ~r"""
           arguments for the default slot in a slotable component are not accessible - instead the arguments from the parent's cols slot will be exposed via `:let={...}`.

           Hint: You can remove these arguments, pull them up to the parent component, or make this component not slotable and use it inside an explicit slot entry:
           ```
           <:cols>
             <Surface.SlotSyncTest.ColumnWithRenderAndSlotArg :let={...}>
               ...
             </Surface.SlotSyncTest.ColumnWithRenderAndSlotArg>
           </:cols>
           ```

             code.exs:11\
           """
  end

  test "don't output compile warning to default slot without argument in a slotable component" do
    component_code = """
    defmodule ColumnWithRender do
      use Surface.Component, slot: "cols"

      slot default

      def render(assigns) do
        ~F"\""
        <#slot {@default} />
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} = Code.eval_string(component_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    refute output =~ "arguments for the default slot in a slotable component are not accessible"
  end

  test "use slot entry in element that is not a component" do
    code =
      quote do
        ~F"""
        <div>
          <:slot />
        </div>
        """
      end

    output =
      capture_io(:standard_error, fn ->
        compile_surface(code, %{})
      end)

    assert output =~
             "cannot render <div> (slot entries are not allowed as children of HTML elements. Did you mean <#slot />?)"

    assert output =~ "code:2:"
  end
end
