defmodule Surface.CompilerTest do
  use ExUnit.Case

  import ComponentTestHelper

  defmodule Macro do
    use Surface.MacroComponent

    def expand(_, _, meta) do
      %Surface.AST.Tag{
        element: "div",
        directives: [],
        attributes: [],
        children: ["I'm a macro"],
        meta: meta
      }
    end
  end

  defmodule Div do
    use Surface.Component

    def render(assigns) do
      ~H"""
      <div><slot /></div>
      """
    end
  end

  defmodule Button do
    use Surface.Component

    property label, :string, default: ""
    property click, :event
    property class, :css_class
    property disabled, :boolean

    def render(assigns) do
      ~H"""
      <button />
      """
    end
  end

  defmodule Column do
    use Surface.Component, slot: "cols"

    property title, :string, required: true
  end

  defmodule ColumnWithoutTitle do
    use Surface.Component, slot: "cols"
  end

  defmodule Grid do
    use Surface.Component

    property items, :list

    slot cols, props: [item: ^items]

    def render(assigns) do
      ~H"""
      """
    end
  end

  defmodule GridLive do
    use Surface.LiveComponent

    property items, :list

    slot cols

    def render(assigns) do
      ~H"""
      <div></div>
      """
    end
  end

  defmodule MyLiveViewWith do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      """
    end
  end

  test "component with expression" do
    code = """
    <Button label={{ @label }}/>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: [
                   %Surface.AST.AttributeExpr{
                     original: " @label ",
                     value: {:@, _, [{:label, _, _}]}
                   }
                 ]
               }
             ]
           } = node
  end

  test "component with expressions inside a string" do
    code = """
    <Button label="str_1 {{@str_2}} str_3 {{@str_4 <> @str_5}}" />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: [
                   %Surface.AST.Text{value: "str_1 "},
                   %Surface.AST.AttributeExpr{
                     original: "@str_2",
                     value: {:@, _, [{:str_2, _, _}]}
                   },
                   %Surface.AST.Text{value: " str_3 "},
                   %Surface.AST.AttributeExpr{
                     original: "@str_4 <> @str_5",
                     value: {:<>, _, [{:@, _, [{:str_4, _, _}]}, {:@, _, [{:str_5, _, _}]}]}
                   }
                 ]
               }
             ]
           } = node
  end

  test "component with events" do
    code = """
    <Button click="click_event" />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :click,
                 type: :event,
                 value: [
                   %Surface.AST.AttributeExpr{
                     value:
                       {{:., _, [{:__aliases__, _, [:Surface]}, :event_value]}, _,
                        [:click, ["click_event"], nil]},
                     original: "click_event"
                   }
                 ]
               }
             ]
           } = node
  end

  test "component with empty :css_class property" do
    code = """
    <Button class="" />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :class,
                 type: :css_class,
                 value: [
                   %Surface.AST.Text{
                     value: ""
                   }
                 ]
               }
             ]
           } = node
  end

  test "component with empty :string property" do
    code = """
    <Button label="" />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: [%Surface.AST.Text{value: ""}]
               }
             ]
           } = node
  end

  test "self-closed component with white spaces between attributes" do
    code = """
    <Button
      label = "label"
      disabled
      click=
        "event"
    />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: [%Surface.AST.Text{value: "label"}]
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: [%Surface.AST.Text{value: true}]
               },
               %Surface.AST.Attribute{
                 name: :click,
                 type: :event,
                 value: [
                   %Surface.AST.AttributeExpr{
                     value:
                       {{:., _, [{:__aliases__, _, [:Surface]}, :event_value]}, _,
                        [:click, ["event"], nil]},
                     original: "event"
                   }
                 ]
               }
             ]
           } = node
  end

  test "regular node component with white spaces between attributes" do
    code = """
    <Button
      label="label"
      disabled
      click=
        "event"
    ></Button>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: [%Surface.AST.Text{value: "label"}]
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: [%Surface.AST.Text{value: true}]
               },
               %Surface.AST.Attribute{
                 name: :click,
                 type: :event,
                 value: [
                   %Surface.AST.AttributeExpr{
                     value:
                       {{:., _, [{:__aliases__, _, [:Surface]}, :event_value]}, _,
                        [:click, ["event"], nil]},
                     original: "event"
                   }
                 ]
               }
             ]
           } = node
  end

  test "HTML node with white spaces between attributes" do
    code = """
    <div
      label="label"
      disabled
      click=
        "event"
    ></div>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Tag{
             element: "div",
             attributes: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: [%Surface.AST.Text{value: "label"}]
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: [%Surface.AST.Text{value: true}]
               },
               %Surface.AST.Attribute{
                 name: :click,
                 type: :string,
                 value: [%Surface.AST.Text{value: "event"}]
               }
             ]
           } = node
  end

  test "HTML node with empty attribute values" do
    code = """
    <div
      label=""
      disabled=""
      class=""
      :on-phx-click=""
    ></div>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Tag{
             element: "div",
             attributes: [
               %Surface.AST.DynamicAttribute{
                 name: :"phx-click",
                 expr: %Surface.AST.AttributeExpr{
                   original: "",
                   # validating that the empty string is treated the same as `nil`
                   value: {:case, _, [nil, _]}
                 }
               },
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: [%Surface.AST.Text{value: ""}]
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: [%Surface.AST.Text{value: true}]
               },
               %Surface.AST.Attribute{
                 name: :class,
                 type: :css_class,
                 value: [%Surface.AST.Text{value: ""}]
               }
             ]
           } = node
  end

  test "LiveView's propeties are forwarded to live_render as options" do
    code = """
    <MyLiveViewWith id="my_id" session={{ %{user_id: 1} }} />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.MyLiveViewWith,
             props: [
               %Surface.AST.Attribute{
                 name: :id,
                 # This is supposedly an integer, but the value is a string
                 # :-(
                 type: :integer,
                 value: [%Surface.AST.Text{value: "my_id"}]
               },
               %Surface.AST.Attribute{
                 name: :session,
                 type: :map,
                 value: [
                   %Surface.AST.AttributeExpr{
                     original: " %{user_id: 1} ",
                     value:
                       {{:., _, [{:__aliases__, _, [:Surface]}, :map_value]}, _,
                        [:session, {:%{}, _, [user_id: 1]}]}
                   }
                 ]
               }
             ]
           } = node
  end

  test "LiveView has no default properties" do
    code = """
    <MyLiveViewWith />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.MyLiveViewWith,
             props: []
           } = node
  end

  test "calling @inner_content.([]) succeeds" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id} do
      use Surface.Component

      def render(assigns) do
        ~H"<div> {{ @inner_content.([]) }} </div>"
      end
    end
    """

    assert {{:module, _, _, _}, _} =
             Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
  end

  test "calling .inner_content.([]) succeeds" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id} do
      use Surface.Component

      def render(assigns) do
        ~H"<div :for={{col <- @cols}}> {{ col.inner_content.([]) }} </div>"
      end
    end
    """

    assert {{:module, _, _, _}, _} =
             Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
  end

  describe "macro components" do
    test "expanded at top level" do
      code = """
      <#Macro />
      """

      [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

      assert %Surface.AST.Container{
               children: [
                 %Surface.AST.Tag{children: ["I'm a macro"], element: "div"}
               ]
             } = node
    end

    test "expanded within a component" do
      code = """
      <Div><#Macro></#Macro></Div>
      """

      [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

      assert %Surface.AST.Component{
               module: Surface.CompilerTest.Div,
               props: [],
               templates: %{
                 default: [
                   %Surface.AST.Template{
                     children: [
                       %Surface.AST.Container{
                         children: [
                           %Surface.AST.Tag{
                             children: ["I'm a macro"],
                             element: "div"
                           }
                         ]
                       }
                     ]
                   }
                 ]
               }
             } = node
    end

    test "expanded within an html tag" do
      code = """
      <div><#Macro /></div>
      """

      [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

      assert %Surface.AST.Tag{
               element: "div",
               children: [
                 %Surface.AST.Container{
                   children: [
                     %Surface.AST.Tag{children: ["I'm a macro"], element: "div"}
                   ]
                 }
               ]
             } = node
    end
  end

  describe "errors/warnings" do
    test "raise error for invalid expressions on properties" do
      code = """
      <div>
        <Button label="label" click="event"/>
        <Button click={{ , }} />
      </div>
      """

      assert_raise(SyntaxError, "nofile:3: syntax error before: ','", fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end)
    end

    test "raise error for invalid expression on interpolation" do
      code = """
      <Grid>
        <ColumnWithoutTitle>
          Test
        </ColumnWithoutTitle>
        <ColumnWithoutTitle>
          {{ , }}
        </ColumnWithoutTitle>
      </Grid>
      """

      assert_raise(SyntaxError, "nofile:6: syntax error before: ','", fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end)
    end

    test "raise error on the right line when properties are defined in multiple lines" do
      code = """
      <div>
        <Button
          label="label"
          click="event"
        />
        <Button click={{ , }} />
      </div>
      """

      assert_raise(SyntaxError, "nofile:6: syntax error before: ','", fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end)
    end

    test "raise error on the right line when components has only data components" do
      code = """
      <Grid items={{ , }}>
        <ColumnWithoutTitle>
          Test
        </ColumnWithoutTitle>
      </Grid>
      """

      assert_raise(SyntaxError, "nofile:1: syntax error before: ','", fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end)
    end

    test "raise error on the right line when error occurs in data components" do
      code = """
      <Grid items={{ user <- users }}>
        <ColumnWithoutTitle>
          Test
        </ColumnWithoutTitle>
        <Column title={{ , }}>
          Test
        </Column>
      </Grid>
      """

      assert_raise(SyntaxError, "nofile:5: syntax error before: ','", fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end)
    end

    test "raise error on the right line when error occurs in live components" do
      code = """
      <GridLive items={{ , }}>
        <ColumnWithoutTitle>
          Test
        </ColumnWithoutTitle>
      </GridLive>
      """

      assert_raise(SyntaxError, "nofile:1: syntax error before: ','", fn ->
        Surface.Compiler.compile(code, 1, __ENV__)
      end)
    end

    test "raise error when calling @inner_content.() instead of @inner_content.([])" do
      id = :erlang.unique_integer([:positive]) |> to_string()

      view_code = """
      defmodule TestLiveComponent_#{id} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <div> {{ @inner_content([]) }} </div>
          "\""
        end
      end
      """

      message = """
      code.exs:6: the `inner_content` anonymous function should be called using \
      the dot-notation. Use `@inner_content.([])` instead of `@inner_content([])`\
      """

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise error when calling @inner_content([]) instead of @inner_content.([])" do
      id = :erlang.unique_integer([:positive]) |> to_string()

      view_code = """
      defmodule TestLiveComponent_#{id} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <div> {{ @inner_content([]) }} </div>
          "\""
        end
      end
      """

      message = """
      code.exs:6: the `inner_content` anonymous function should be called using \
      the dot-notation. Use `@inner_content.([])` instead of `@inner_content([])`\
      """

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise error when calling @inner_content() instead of @inner_content.([])" do
      id = :erlang.unique_integer([:positive]) |> to_string()

      view_code = """
      defmodule TestLiveComponent_#{id} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <div> {{ @inner_content([]) }} </div>
          "\""
        end
      end
      """

      message = """
      code.exs:6: the `inner_content` anonymous function should be called using \
      the dot-notation. Use `@inner_content.([])` instead of `@inner_content([])`\
      """

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise error when calling .inner_content.() instead of .inner_content.([])" do
      id = :erlang.unique_integer([:positive]) |> to_string()

      view_code = """
      defmodule TestLiveComponent_#{id} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <div> {{ col.inner_content() }} </div>
          "\""
        end
      end
      """

      message =
        "code.exs:6: the `inner_content` anonymous function should be called using " <>
          "the dot-notation. Use `col.inner_content.([])` instead of `col.inner_content()`"

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise error when calling .inner_content.(test: 1) instead of .inner_content.(test: 1)" do
      id = :erlang.unique_integer([:positive]) |> to_string()

      view_code = """
      defmodule TestLiveComponent_#{id} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <div> {{ col.inner_content(prop: 1) }} </div>
          "\""
        end
      end
      """

      message =
        "code.exs:6: the `inner_content` anonymous function should be called using " <>
          "the dot-notation. Use `col.inner_content.(prop: 1)` instead of `col.inner_content(prop: 1)`"

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise error when calling .inner_content() instead of .inner_content.([])" do
      id = :erlang.unique_integer([:positive]) |> to_string()

      view_code = """
      defmodule TestLiveComponent_#{id} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <div> {{ col.inner_content() }} </div>
          "\""
        end
      end
      """

      message =
        "code.exs:6: the `inner_content` anonymous function should be called using " <>
          "the dot-notation. Use `col.inner_content.([])` instead of `col.inner_content()`"

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end

    test "raise error when calling .inner_content([]) instead of .inner_content.([])" do
      id = :erlang.unique_integer([:positive]) |> to_string()

      view_code = """
      defmodule TestLiveComponent_#{id} do
        use Surface.Component

        def render(assigns) do
          ~H"\""
          <div> {{ col.inner_content([]) }} </div>
          "\""
        end
      end
      """

      message =
        "code.exs:6: the `inner_content` anonymous function should be called using " <>
          "the dot-notation. Use `col.inner_content.([])` instead of `col.inner_content([])`"

      assert_raise(CompileError, message, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)
    end
  end
end

defmodule Surface.CompilerSyncTest do
  use ExUnit.Case

  import ExUnit.CaptureIO
  import ComponentTestHelper

  alias Surface.CompilerTest.{Button, Column}, warn: false

  test "warning when component cannot be loaded" do
    code = """
    <div>
      <But />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ "cannot render <But> (module But could not be loaded)"
    assert line == 2
  end

  test "warning when module is not a component" do
    code = """
    <div>
      <Enum />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ "cannot render <Enum> (module Enum is not a component)"
    assert line == 2
  end

  test "warning on non-existent property" do
    code = """
    <div>
      <Button
        label="test"
        nonExistingProp="1"
      />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ ~S(Unknown property "nonExistingProp" for component <Button>)
    assert line == 4
  end

  test "warning on missing required property" do
    code = """
    <Column />
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ ~S(Missing required property "title" for component <Column>)
    assert line == 1
  end

  test "warning on stateful components with more than one root element" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id} do
      use Surface.LiveComponent

      def render(assigns) do
        ~H"\""
        <div>1</div><div>2</div>
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ "stateful live components must have a single HTML root element"
    assert extract_line(output) == 6
  end

  test "warning on stateful components with text root element" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id} do
      use Surface.LiveComponent

      def render(assigns) do
        ~H"\""
        just text
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ "stateful live components must have a HTML root element"
    assert extract_line(output) == 6
  end

  test "warning on stateful components with interpolation root element" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id} do
      use Surface.LiveComponent

      def render(assigns) do
        ~H"\""
        {{ 1 }}
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ "stateful live components must have a HTML root element"
    assert extract_line(output) == 6
  end

  defp run_compile(code, env) do
    env = %{env | line: 1}

    output =
      capture_io(:standard_error, fn ->
        result = Surface.Compiler.compile(code, 1, env)
        send(self(), {:result, result})
      end)

    result =
      receive do
        {:result, result} -> result
      end

    case output do
      "" ->
        {:ok, result}

      message ->
        {:warn, extract_line(output), message}
    end
  end
end
