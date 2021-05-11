defmodule Surface.CompilerTest do
  use ExUnit.Case

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

    slot default

    def render(assigns) do
      ~H"""
      <div><#slot /></div>
      """
    end
  end

  defmodule Button do
    use Surface.Component

    prop label, :string, default: "", root: true
    prop click, :event
    prop class, :css_class
    prop disabled, :boolean

    def render(assigns) do
      ~H"""
      <button />
      """
    end
  end

  defmodule Column do
    use Surface.Component, slot: "cols"

    prop title, :string, required: true
  end

  defmodule ColumnWithoutTitle do
    use Surface.Component, slot: "cols"
  end

  defmodule Grid do
    use Surface.Component

    prop items, :list

    slot cols, props: [item: ^items]

    def render(assigns) do
      ~H"""
      """
    end
  end

  defmodule GridLive do
    use Surface.LiveComponent

    prop items, :list

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

  test "ignore comments" do
    code = """
    <br>
    <!-- comment -->
    <hr>
    """

    nodes = Surface.Compiler.compile(code, 1, __ENV__)

    assert [
             %Surface.AST.VoidTag{element: "br"},
             %Surface.AST.Literal{value: "\n"},
             %Surface.AST.Literal{value: "\n"},
             %Surface.AST.VoidTag{element: "hr"},
             %Surface.AST.Literal{value: "\n"}
           ] = nodes
  end

  test "component with expression" do
    code = """
    <Button label={@label}/>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: %Surface.AST.AttributeExpr{
                   original: "@label",
                   value: {_, _, [_, _, [{:@, _, [{:label, _, _}]}], [], _, _]}
                 }
               }
             ]
           } = node
  end

  test "component with expression using special characters in interpolation" do
    code = """
    <h2>{"héllo"}</h2>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Tag{
             children: [
               %Surface.AST.Interpolation{
                 original: "\"héllo\"",
                 value: "héllo"
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
                 value: %Surface.AST.AttributeExpr{
                   value: _,
                   original: "click_event"
                 }
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
                 value: %Surface.AST.Literal{value: ""}
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
                 value: %Surface.AST.Literal{value: ""}
               }
             ]
           } = node
  end

  test "component with root property" do
    code = """
    <Button {"click"} />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.Button,
             props: [
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: %Surface.AST.AttributeExpr{
                   original: "\"click\""
                 }
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
                 value: %Surface.AST.Literal{value: "label"}
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: %Surface.AST.Literal{value: true}
               },
               %Surface.AST.Attribute{
                 name: :click,
                 type: :event,
                 value: %Surface.AST.AttributeExpr{
                   value: _expr,
                   original: "event"
                 }
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
                 value: %Surface.AST.Literal{value: "label"}
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: %Surface.AST.Literal{value: true}
               },
               %Surface.AST.Attribute{
                 name: :click,
                 type: :event,
                 value: %Surface.AST.AttributeExpr{
                   value: _expr,
                   original: "event"
                 }
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
                 value: %Surface.AST.Literal{value: "label"}
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: %Surface.AST.Literal{value: true}
               },
               %Surface.AST.Attribute{
                 name: :click,
                 type: :string,
                 value: %Surface.AST.Literal{value: "event"}
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
      :on-click=""
    ></div>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Tag{
             element: "div",
             attributes: [
               %Surface.AST.DynamicAttribute{
                 name: :click,
                 expr: %Surface.AST.AttributeExpr{
                   original: "",
                   value: _
                 }
               },
               %Surface.AST.Attribute{
                 name: :label,
                 type: :string,
                 value: %Surface.AST.Literal{value: ""}
               },
               %Surface.AST.Attribute{
                 name: :disabled,
                 type: :boolean,
                 value: %Surface.AST.Literal{value: true}
               },
               %Surface.AST.Attribute{
                 name: :class,
                 type: :css_class,
                 value: %Surface.AST.Literal{value: ""}
               }
             ]
           } = node
  end

  test "LiveView's propeties are forwarded to live_render as options" do
    code = """
    <MyLiveViewWith id="my_id" session={%{user_id: 1}} />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.MyLiveViewWith,
             props: [
               %Surface.AST.Attribute{
                 name: :id,
                 type: :string,
                 value: %Surface.AST.Literal{value: "my_id"}
               },
               %Surface.AST.Attribute{
                 name: :session,
                 type: :map,
                 value: %Surface.AST.AttributeExpr{
                   original: "%{user_id: 1}",
                   value: _
                 }
               }
             ]
           } = node
  end

  test "LiveView has no default properties" do
    code = """
    <MyLiveViewWith id="live_view" />
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Component{
             module: Surface.CompilerTest.MyLiveViewWith,
             props: [
               %Surface.AST.Attribute{name: :id, type: :string}
             ]
           } = node
  end

  describe "macro components" do
    test "inject a __compile_dep__/0 macro call to force compile-time dependency" do
      code = """
      <#Macro />
      """

      [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

      assert %Surface.AST.Container{
               children: [
                 %Surface.AST.Expr{value: {{:., _, [{:require, _, _}, :__compile_dep__]}, _, []}},
                 %Surface.AST.Tag{}
               ]
             } = node
    end

    test "expanded at top level" do
      code = """
      <#Macro />
      """

      [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

      assert %Surface.AST.Container{
               children: [
                 _,
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
                           _,
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
                     %Surface.AST.Expr{},
                     %Surface.AST.Tag{children: ["I'm a macro"], element: "div"}
                   ]
                 }
               ]
             } = node
    end

    test "#raw is treated as a Literal" do
      code = """
      <div>
        <#raw>
          I am a macro
        </#raw>
      </div>
      """

      [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

      assert %Surface.AST.Tag{
               element: "div",
               children: [
                 %Surface.AST.Literal{value: "\n  "},
                 %Surface.AST.Literal{value: "\n    I am a macro\n  "},
                 %Surface.AST.Literal{value: "\n"}
               ]
             } = node
    end
  end

  describe "constructs" do
    test "#if/#elseif/#else" do
      code = """
      <div>
        <#if condition={false}>
          IF
        <#elseif condition={false}>
          ELSEIF FALSE
        <#elseif condition={true}>
          BEFORE
          <#if condition={false}>
            NESTED IF
          <#elseif condition={true}>
            NESTED ELSEIF TRUE
          <#else>
            NESTED ELSE
          </#if>
          AFTER
        <#else>
          ELSE
        </#if>
      </div>
      """

      [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

      assert %Surface.AST.Tag{
               element: "div",
               children: [
                 %Surface.AST.Literal{value: "\n  "},
                 %Surface.AST.If{
                   condition: %Surface.AST.AttributeExpr{original: "false"},
                   children: [%Surface.AST.Literal{value: "\n    IF\n  "}],
                   else: [
                     %Surface.AST.If{
                       condition: %Surface.AST.AttributeExpr{original: "false"},
                       children: [%Surface.AST.Literal{value: "\n    ELSEIF FALSE\n  "}],
                       else: [
                         %Surface.AST.If{
                           condition: %Surface.AST.AttributeExpr{original: "true"},
                           children: [
                             %Surface.AST.Literal{value: "\n    BEFORE\n    "},
                             %Surface.AST.If{
                               condition: %Surface.AST.AttributeExpr{original: "false"},
                               children: [%Surface.AST.Literal{value: "\n      NESTED IF\n    "}],
                               else: [
                                 %Surface.AST.If{
                                   condition: %Surface.AST.AttributeExpr{original: "true"},
                                   children: [
                                     %Surface.AST.Literal{
                                       value: "\n      NESTED ELSEIF TRUE\n    "
                                     }
                                   ],
                                   else: [
                                     %Surface.AST.Container{
                                       children: [
                                         %Surface.AST.Literal{value: "\n      NESTED ELSE\n    "}
                                       ]
                                     }
                                   ]
                                 }
                               ]
                             },
                             %Surface.AST.Literal{value: "\n    AFTER\n  "}
                           ],
                           else: [
                             %Surface.AST.Container{
                               children: [
                                 %Surface.AST.Literal{value: "\n    ELSE\n  "}
                               ]
                             }
                           ]
                         }
                       ]
                     }
                   ]
                 },
                 %Surface.AST.Literal{value: "\n"}
               ]
             } = node
    end
  end

  test "#unless" do
    code = """
    <div>
      <#unless condition={false}>
        UNLESS
      </#unless>
    </div>
    """

    [node | _] = Surface.Compiler.compile(code, 1, __ENV__)

    assert %Surface.AST.Tag{
             element: "div",
             children: [
               %Surface.AST.Literal{value: "\n  "},
               %Surface.AST.If{
                 children: [],
                 condition: %Surface.AST.AttributeExpr{original: "false"},
                 else: [
                   %Surface.AST.Literal{value: "\n    UNLESS\n  "}
                 ]
               },
               %Surface.AST.Literal{value: "\n"}
             ]
           } = node
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
  end
end

defmodule Surface.CompilerSyncTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias Surface.CompilerTest.{Button, Column, GridLive}, warn: false

  test "warning when passing integer attribute values that are not enclosed by {}" do
    code = """
    <div>
      <div tabindex=1 />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ """
            passing unquoted attribute values has been deprecated and will be removed in future versions.

             Hint: replace `tabindex=1` with `tabindex={1}`
           """

    assert line == 2
  end

  test "warning when passing boolean attribute values that are not enclosed by {}" do
    code = """
    <div>
      <div selected=true checked=false />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ """
            passing unquoted attribute values has been deprecated and will be removed in future versions.

             Hint: replace `selected=true` with `selected={true}`
           """

    assert message =~ """
            passing unquoted attribute values has been deprecated and will be removed in future versions.

             Hint: replace `checked=false` with `checked={false}`
           """

    assert line == 2
  end

  test "warning when a aliased component cannot be loaded" do
    alias Components.But, warn: false

    code = """
    <div>
      <But />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ ~r/cannot render <But> \(module Components.But could not be loaded\)\s*/
    assert line == 2
  end

  test "warning with hint when a unaliased component cannot be loaded" do
    code = """
    <div>
      <But />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ """
           cannot render <But> (module But could not be loaded)

           Hint: Make sure module `But` can be successfully compiled.

           If the module is namespaced, you can use its full name. For instance:

             <MyProject.Components.But>

           or add a proper alias so you can use just `<But>`:

             alias MyProject.Components.But
           """

    assert line == 2
  end

  test "warning when module is not a component" do
    alias List.Chars, warn: false

    code = """
    <div>
      <Chars />
    </div>
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ "cannot render <Chars> (module List.Chars is not a component)"
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

  test "warning on undefined assign in property" do
    code = """
    <div prop={{ @assign }} />
    """

    {:warn, line, message} = compile_component(code)

    assert message =~ ~S(undefined assign `@assign`.)
    assert line == 1
  end

  test "warning on undefined assign in interpolation" do
    code = """
    <div>
      {{ @assign }}
    </div>
    """

    {:warn, line, message} = compile_component(code)

    assert message =~ ~S(undefined assign `@assign`.)
    assert line == 2
  end

  test "warning on missing required property" do
    code = """
    <Column />
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ ~S(Missing required property "title" for component <Column>)
    assert line == 1
  end

  test "warning on missing id for LiveComponent" do
    code = """
    <GridLive />
    """

    {:warn, line, message} = run_compile(code, __ENV__)

    assert message =~ ~S"""
           Missing required property "id" for component <GridLive>

           Hint: Components using `Surface.LiveComponent` automatically define a required `id` prop to make them stateful.
           If you meant to create a stateless component, you can switch to `use Surface.Component`.
           """

    assert line == 1
  end

  test "disable warning on missing required property when :props is passed" do
    code = """
    <Column :props={title: "My Title"}/>
    """

    assert {:ok, _result} = run_compile(code, __ENV__)
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

  test "does not warn if H_sigil is used outside a render function of a component" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id} do
      use Surface.Component

      def render(assigns) do
        ~H"\""
        <div>
          {{ sum(assigns) }}
        </div>
        "\""
      end

      def sum(assigns) do
        ~H"\""
        {{ @a + @b }}
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output == ""
  end

  test "does not warn if H_sigil is used outside a render function of a live component" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id} do
      use Surface.LiveComponent

      def render(assigns) do
        ~H"\""
        <div>
          {{ sum(assigns) }}
        </div>
        "\""
      end

      def sum(assigns) do
        ~H"\""
        {{ @a + @b }}
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output == ""
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

  test "warning on stateful components with other stateful component as root element" do
    id_1 = :erlang.unique_integer([:positive]) |> to_string()
    id_2 = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestLiveComponent_#{id_1} do
      use Surface.LiveComponent

      def render(assigns) do
        ~H"\""
        <div>Foo</div>
        "\""
      end
    end
    defmodule TestLiveComponent_#{id_2} do
      use Surface.LiveComponent

      def render(assigns) do
        ~H"\""
          <TestLiveComponent_#{id_1} id="#{id_1}" />
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ """
           cannot have a LiveComponent as root node of another LiveComponent.

           Hint: You can wrap the root `TestLiveComponent_#{id_1}` node in another element. Example:

             def render(assigns) do
               ~H"\""
               <div>
                 <TestLiveComponent_#{id_1} ... >
                   ...
                 </TestLiveComponent_#{id_1}>
               </div>
               "\""
             end

             code.exs:15: Surface.CompilerSyncTest.TestLiveComponent_#{id_2}.render/1

           """
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

  test "warning on component with required slot that has a default value" do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code = """
    defmodule TestComponent_#{id} do
      use Surface.Component

      slot default, required: true
      slot header, required: true
      slot footer

      def render(assigns) do
        ~H"\""
        <div>
          <#slot>Default Content</#slot>
          <#slot name="header">Default Header</#slot>
          <#slot name="footer">Default Footer</#slot>
        </div>
        "\""
      end
    end
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, _, _, _}, _} =
          Code.eval_string(view_code, [], %{__ENV__ | file: "code.exs", line: 1})
      end)

    assert output =~ """
           setting the fallback content on a required slot has no effect.

           Hint: Either keep the fallback content and remove the `required: true`:

             slot default
             ...
             <#slot>Fallback content</#slot>

           or keep the slot as required and remove the fallback content:

             slot default, required: true`
             ...
             <#slot />

           but not both.

             code.exs:11: Surface.CompilerSyncTest.TestComponent_#{id}.render/1

           """

    assert output =~ """
           setting the fallback content on a required slot has no effect.

           Hint: Either keep the fallback content and remove the `required: true`:

             slot header
             ...
             <#slot name="header">Fallback content</#slot>

           or keep the slot as required and remove the fallback content:

             slot header, required: true`
             ...
             <#slot name="header" />

           but not both.

             code.exs:12: Surface.CompilerSyncTest.TestComponent_#{id}.render/1

           """
  end

  defp compile_component(code) do
    id = :erlang.unique_integer([:positive]) |> to_string()

    component_code = """
    defmodule CompilerTestComponent_#{id} do; \
      use Surface.Component; \
      def render(assigns) do; \
        ~H"#{code}" \
      end; \
    end\
    """

    output =
      capture_io(:standard_error, fn ->
        {{:module, module, _, _}, _} = Code.eval_string(component_code, [], %{__ENV__ | line: 1})

        send(self(), {:result, module})
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

  defp extract_line(message) do
    case Regex.run(~r/.exs:(\d+)/, message) do
      [_, line] ->
        String.to_integer(line)

      _ ->
        :not_found
    end
  end
end
