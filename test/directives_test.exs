defmodule Surface.DirectivesTest do
  use Surface.ConnCase, async: true

  defmodule Div do
    use Surface.Component

    slot default

    def render(assigns) do
      ~H"""
      <div><#slot/></div>
      """
    end
  end

  defmodule DivWithProps do
    use Surface.Component

    prop class, :string
    prop hidden, :boolean
    prop content, :string

    def render(assigns) do
      ~H"""
      <div class={@class, hidden: @hidden, block: !@hidden}>
        {@content}
      </div>
      """
    end
  end

  defmodule DivWithSlotUsingIf do
    use Surface.Component

    prop show, :boolean
    slot default

    def render(assigns) do
      ~H"""
      <div><#slot :if={@show}/></div>
      """
    end
  end

  defmodule DivWithSlotUsingIfAndProps do
    use Surface.Component

    prop show, :boolean
    slot default, props: [:data]

    def render(assigns) do
      ~H"""
      <div><#slot :if={@show} :props={data: "data"}/></div>
      """
    end
  end

  defmodule DivWithSlotUsingFor do
    use Surface.Component

    prop repeat, :integer
    slot default

    def render(assigns) do
      ~H"""
      <div><#slot :for={_i <- 1..@repeat}/></div>
      """
    end
  end

  describe ":props for a component" do
    test "passing keyword list of props" do
      html =
        render_surface do
          ~H"""
          <DivWithProps :props={class: "text-xs", hidden: false, content: "dynamic props content"} />
          """
        end

      assert html =~ """
             <div class="text-xs block">
               dynamic props content
             </div>
             """
    end

    test "static props override dynamic props" do
      html =
        render_surface do
          ~H"""
          <DivWithProps content="static content" :props={class: "text-xs", hidden: false, content: "dynamic props content"} />
          """
        end

      assert html =~ """
             <div class="text-xs block">
               static content
             </div>
             """
    end

    test "using an assign" do
      assigns = %{opts: %{class: "text-xs", hidden: false, content: "dynamic props content"}}

      html =
        render_surface do
          ~H"""
          <DivWithProps :props={@opts} />
          """
        end

      assert html =~ """
             <div class="text-xs block">
               dynamic props content
             </div>
             """
    end
  end

  describe ":attrs in html tags" do
    test "passing a keyword list" do
      html =
        render_surface do
          ~H"""
          <div class="myclass" :attrs={id: "myid"}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div id="myid" class="myclass">
               Some Text
             </div>
             """
    end

    test "passing a map" do
      html =
        render_surface do
          ~H"""
          <div class="myclass" :attrs={%{id: "myid"}}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div id="myid" class="myclass">
               Some Text
             </div>
             """
    end

    test "using an assign" do
      assigns = %{div_props: [id: "myid", "aria-label": "A div"]}

      html =
        render_surface do
          ~H"""
          <div class="myclass" :attrs={@div_props}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div aria-label="A div" id="myid" class="myclass">
               Some Text
             </div>
             """
    end

    test "with boolean properties" do
      html =
        render_surface do
          ~H"""
          <div class="myclass" :attrs={disabled: true}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div disabled class="myclass">
               Some Text
             </div>
             """
    end

    test "static properties override dynamic properties" do
      html =
        render_surface do
          ~H"""
          <div class="myclass" id="static-id" :attrs={id: "dynamic-id"}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div class="myclass" id="static-id">
               Some Text
             </div>
             """
    end
  end

  describe "modifiers" do
    test "using multiple modifiers" do
      assigns = %{items: [:a, :b]}

      html =
        render_surface do
          ~H"""
          <div :for.index.with_index={{i, j} <- @items}>
            i: {i}, j: {j}
          </div>
          """
        end

      assert html =~ """
             <div>
               i: 0, j: 0
             </div><div>
               i: 1, j: 1
             </div>
             """
    end

    test "modifiers on components" do
      assigns = %{items: [1, 2]}

      html =
        render_surface do
          ~H"""
          <Div :for.with_index={{iii, index} <- @items}>
            Item: {iii}, Index: {index}
          </Div>
          """
        end

      assert html =~ """
             <div>
               Item: 1, Index: 0
             </div>
             <div>
               Item: 2, Index: 1
             </div>
             """
    end

    test "raise compile error for unknown modifiers" do
      assigns = %{items: [%{id: 1, name: "First"}]}

      code =
        quote do
          ~H"""
          <br/>
          <div :for.unknown={@items}>
            Index: {index}
          </div>
          """
        end

      message = """
      code:2: unknown modifier "unknown" for directive :for\
      """

      assert_raise(CompileError, message, fn ->
        compile_surface(code, assigns)
      end)
    end

    test "raise compile error for modifiers with multiple clauses" do
      assigns = %{a: [1, 2], b: [1, 2]}

      code =
        quote do
          ~H"""
          <br/>
          <div :for.with_index={i <- a, j <- b}>
            Index: {index}
          </div>
          """
        end

      message = """
      code:2: cannot apply modifier "with_index" on generators with multiple clauses\
      """

      assert_raise(CompileError, message, fn ->
        compile_surface(code, assigns)
      end)
    end
  end

  describe ":for" do
    test "in components" do
      assigns = %{items: [1, 2]}

      html =
        render_surface do
          ~H"""
          <Div :for={i <- @items}>
            Item: {i}
          </Div>
          """
        end

      assert html =~ """
             <div>
               Item: 1
             </div>
             <div>
               Item: 2
             </div>
             """
    end

    test "in html tags" do
      assigns = %{items: [1, 2]}

      html =
        render_surface do
          ~H"""
          <div :for={i <- @items}>
            Item: {i}
          </div>
          """
        end

      assert html =~ """
             <div>
               Item: 1
             </div><div>
               Item: 2
             </div>
             """
    end

    test "in void html elements" do
      html =
        render_surface do
          ~H"""
          <br :for={_ <- [1,2]}>
          """
        end

      assert html == """
             <br><br>
             """
    end

    test "in slots" do
      html =
        render_surface do
          ~H"""
          <DivWithSlotUsingFor repeat={3}>
            <span>surface</span>
          </DivWithSlotUsingFor>
          """
        end

      assert html == """
             <div>
               <span>surface</span>
               <span>surface</span>
               <span>surface</span>
             </div>
             """
    end

    test "with larger generator expression" do
      assigns = %{items1: [1, 2], items2: [3, 4]}

      html =
        render_surface do
          ~H"""
          <div :for={i1 <- @items1, i2 <- @items2, i1 < 4}>
            Item1: {i1}
            Item2: {i2}
          </div>
          """
        end

      assert html =~ """
             <div>
               Item1: 1
               Item2: 3
             </div>\
             <div>
               Item1: 1
               Item2: 4
             </div>\
             <div>
               Item1: 2
               Item2: 3
             </div>\
             <div>
               Item1: 2
               Item2: 4
             </div>
             """
    end

    test "with_index modifier" do
      assigns = %{items: [1, 2]}

      html =
        render_surface do
          ~H"""
          <div :for.with_index={{item, index} <- @items}>
            Item: {item}, Index: {index}
          </div>
          """
        end

      assert html =~ """
             <div>
               Item: 1, Index: 0
             </div><div>
               Item: 2, Index: 1
             </div>
             """
    end

    test "index modifier with generator" do
      assigns = %{items: [1, 2]}

      html =
        render_surface do
          ~H"""
          <div :for.index={index <- @items}>
            Index: {index}
          </div>
          """
        end

      assert html =~ """
             <div>
               Index: 0
             </div><div>
               Index: 1
             </div>
             """
    end

    test "index modifier with list" do
      assigns = %{items: [1, 2]}

      html =
        render_surface do
          ~H"""
          <div :for.index={@items}>
            Index: {index}
          </div>
          """
        end

      assert html =~ """
             <div>
               Index: 0
             </div><div>
               Index: 1
             </div>
             """
    end
  end

  describe ":if" do
    test "in components" do
      assigns = %{show: true, dont_show: false}

      html =
        render_surface do
          ~H"""
          <Div :if={@show}>
            Show
          </Div>
          <Div :if={@dont_show}>
            Dont's show
          </Div>
          """
        end

      assert html == """
             <div>
               Show
             </div>
             """
    end

    test "in html tags" do
      assigns = %{show: true, dont_show: false}

      html =
        render_surface do
          ~H"""
          <div :if={@show}>
            Show
          </div>
          <div :if={@dont_show}>
            Dont's show
          </div>
          """
        end

      assert html =~ """
             <div>
               Show
             </div>
             """
    end

    test "in void html elements" do
      assigns = %{show: true, dont_show: false}

      html =
        render_surface do
          ~H"""
          <col class="show" :if={@show}>
          <col class="dont_show" :if={@dont_show}>
          """
        end

      assert html == """
             <col class="show">
             """
    end

    test "in slots" do
      html =
        render_surface do
          ~H"""
          <DivWithSlotUsingIf show={true}>1</DivWithSlotUsingIf>
          <DivWithSlotUsingIf show={false}>2</DivWithSlotUsingIf>
          <DivWithSlotUsingIf show={true}>3</DivWithSlotUsingIf>
          """
        end

      assert html == """
             <div>1</div>
             <div></div>
             <div>3</div>
             """
    end

    test "in slots with props" do
      html =
        render_surface do
          ~H"""
          <DivWithSlotUsingIfAndProps show={true} :let={data: d}>1 - {d}</DivWithSlotUsingIfAndProps>
          <DivWithSlotUsingIfAndProps show={false} :let={data: d}>2 - {d}</DivWithSlotUsingIfAndProps>
          <DivWithSlotUsingIfAndProps show={true} :let={data: d}>3 - {d}</DivWithSlotUsingIfAndProps>
          """
        end

      assert html == """
             <div>1 - data</div>
             <div></div>
             <div>3 - data</div>
             """
    end
  end

  describe ":show" do
    test "when true, do nothing" do
      assigns = %{show: true}

      html =
        render_surface do
          ~H"""
          <col :show={@show}>
          <col :show={true}>
          """
        end

      assert html == """
             <col>
             <col>
             """
    end

    test "when false, add hidden attribute" do
      assigns = %{show: false}

      html =
        render_surface do
          ~H"""
          <col :show={@show}>
          """
        end

      assert html == """
             <col hidden>
             """
    end

    test "when false literal, add hidden attribute" do
      html =
        render_surface do
          ~H"""
          <col :show={false}>
          """
        end

      assert html == """
             <col hidden>
             """
    end
  end

  describe ":on-*" do
    test "as an event map" do
      assigns = %{click: %{name: "ok", target: "#comp"}}

      html =
        render_surface do
          ~H"""
          <button :on-click={@click}>OK</button>
          """
        end

      assert html =~ """
             <button phx-click="ok" phx-target="#comp">OK</button>
             """
    end

    test "as a string" do
      assigns = %{click: "ok"}

      html =
        render_surface do
          ~H"""
          <button :on-click={@click}>OK</button>
          """
        end

      assert html =~ """
             <button phx-click="ok">OK</button>
             """
    end

    test "as a literal string" do
      html =
        render_surface do
          ~H"""
          <button :on-click="ok">OK</button>
          """
        end

      assert html =~ """
             <button phx-click="ok">OK</button>
             """
    end

    test "as event name + target option" do
      html =
        render_surface do
          ~H"""
          <button :on-click={"ok", target: "#comp"}>OK</button>
          """
        end

      assert html =~ """
             <button phx-click="ok" phx-target="#comp">OK</button>
             """
    end

    test "do not translate invalid events" do
      html =
        render_surface do
          ~H"""
          <button :on-invalid="ok">OK</button>
          """
        end

      assert html =~ """
             <button :on-invalid="ok">OK</button>
             """
    end
  end

  describe ":hook" do
    test "generate phx-hook with __MODULE__ as default namespace" do
      html =
        render_surface do
          ~H"""
          <div :hook="Button"></div>
          """
        end

      assert html =~ """
             <div phx-hook="Surface.DirectivesTest#Button"></div>
             """
    end

    test "generate phx-hook with custom namespace" do
      html =
        render_surface do
          ~H"""
          <div :hook={"Button", from: Some.Fake.Comp}></div>
          """
        end

      assert html =~ """
             <div phx-hook="Some.Fake.Comp#Button"></div>
             """
    end

    test "don't generate anything if the value is nil or false" do
      html =
        render_surface do
          ~H"""
          <div :hook={nil}></div>
          """
        end

      assert html =~ """
             <div></div>
             """

      html =
        render_surface do
          ~H"""
          <div :hook={nil, from: Some.Fake.Comp}></div>
          """
        end

      assert html =~ """
             <div></div>
             """

      html =
        render_surface do
          ~H"""
          <div :hook={false}></div>
          """
        end

      assert html =~ """
             <div></div>
             """

      html =
        render_surface do
          ~H"""
          <div :hook={false, from: Some.Fake.Comp}></div>
          """
        end

      assert html =~ """
             <div></div>
             """
    end
  end

  describe ":values" do
    test "passing a keyword list" do
      html =
        render_surface do
          ~H"""
          <div :values={hello: :world, foo: "bar", one: 2, yes: true}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div phx-value-foo="bar" phx-value-hello="world" phx-value-one="2" phx-value-yes="true">
               Some Text
             </div>
             """
    end

    test "passing a map" do
      html =
        render_surface do
          ~H"""
          <div :values={%{hello: :world, foo: "bar", one: 2, yes: true}}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div phx-value-foo="bar" phx-value-hello="world" phx-value-one="2" phx-value-yes="true">
               Some Text
             </div>
             """
    end

    test "passing unsupported types" do
      assert_raise(RuntimeError, ~r(invalid value for key ":map" in attribute ":values".), fn ->
        render_surface do
          ~H"""
          <div :values={map: %{}, tuple: {}}>
            Some Text
          </div>
          """
        end
      end)
    end

    test "using an assign" do
      assigns = %{values: [hello: :world, foo: "bar", one: 2, yes: true]}

      html =
        render_surface do
          ~H"""
          <div :values={@values}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div phx-value-foo="bar" phx-value-hello="world" phx-value-one="2" phx-value-yes="true">
               Some Text
             </div>
             """
    end

    test "static properties override dynamic properties" do
      html =
        render_surface do
          ~H"""
          <div phx-value-hello="static-world" :values={hello: "dynamic-world"}>
            Some Text
          </div>
          """
        end

      assert html =~ """
             <div phx-value-hello="static-world">
               Some Text
             </div>
             """
    end
  end
end

defmodule Surface.DirectivesSyncTest do
  use Surface.ConnCase

  import ExUnit.CaptureIO

  alias Surface.DirectivesTest.{DivWithProps}

  describe ":props on a component" do
    test "emits a warning with an unknown prop at runtime" do
      assigns = %{
        opts: %{
          unknown: "value",
          class: "text-xs",
          hidden: false,
          content: "dynamic props content"
        }
      }

      message =
        capture_io(:standard_error, fn ->
          render_surface do
            ~H"""
            <DivWithProps :props={@opts} />
            """
          end
        end)

      assert message =~ ~S|Unknown property "unknown" for component <DivWithProps>|
    end
  end
end
