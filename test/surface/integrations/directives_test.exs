defmodule Surface.DirectivesTest do
  use Surface.ConnCase, async: true

  alias Phoenix.LiveView.JS

  defmodule Div do
    use Surface.Component

    slot default

    def render(assigns) do
      ~F"""
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
      ~F"""
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
      ~F"""
      <div><#slot :if={@show}/></div>
      """
    end
  end

  defmodule DivWithSlotUsingIfAndProps do
    use Surface.Component

    prop show, :boolean
    slot default, arg: %{data: :string}

    def render(assigns) do
      ~F"""
      <div><#slot :if={@show} {@default, data: "data"}/></div>
      """
    end
  end

  defmodule DivWithSlotUsingFor do
    use Surface.Component

    prop repeat, :integer
    slot default

    def render(assigns) do
      ~F"""
      <div><#slot :for={_i <- 1..@repeat}/></div>
      """
    end
  end

  test "directive with \":\" prefix" do
    html =
      render_surface do
        ~F"""
        <div :attrs={class: "text-xs"} />
        """
      end

    assert html =~ ~s(<div class="text-xs"></div>)
  end

  test "directive with \"s-\" prefix" do
    html =
      render_surface do
        ~F"""
        <div s-attrs={class: "text-xs"} />
        """
      end

    assert html =~ ~s(<div class="text-xs"></div>)
  end

  describe ":props for a component" do
    test "passing keyword list of props" do
      html =
        render_surface do
          ~F"""
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
          ~F"""
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
          ~F"""
          <DivWithProps :props={@opts} />
          """
        end

      assert html =~ """
             <div class="text-xs block">
               dynamic props content
             </div>
             """
    end

    test "using assign, static props override dynamic props" do
      assigns = %{props: %{class: "text-xs", hidden: true, content: "dynamic props content"}}

      html =
        render_surface do
          ~F"""
          <DivWithProps content="static content" :props={@props} />
          """
        end

      assert html =~ """
             <div class="text-xs hidden">
               static content
             </div>
             """
    end

    test "shorthand notation `{...@props}`" do
      assigns = %{props: %{class: "text-xs", hidden: false, content: "dynamic props content"}}

      html =
        render_surface do
          ~F"""
          <DivWithProps {...@props} />
          """
        end

      assert html =~ """
             <div class="text-xs block">
               dynamic props content
             </div>
             """
    end

    test "raise if trying to assisn `{... }` to a property" do
      assigns = %{props: %{}}

      code =
        quote do
          ~F"""
          <DivWithProps
            class=
              {...@props} />
          """
        end

      message = ~r"""
      code:3:
      #{maybe_ansi("error:")} cannot assign `{\.\.\.@props}` to attribute `class`\. \
      The tagged expression `{\.\.\. }` can only be used on a root attribute/property\.

      Example: <div {\.\.\.@attrs}>
      """

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code, assigns)
      end)
    end
  end

  describe ":attrs in html tags" do
    test "passing a keyword list" do
      html =
        render_surface do
          ~F"""
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
          ~F"""
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
          ~F"""
          <div class="myclass" :attrs={@div_props}>
            Some Text
          </div>
          """
        end

      doc = parse_document!(html)

      assert attribute(doc, "id") == ["myid"]
      assert attribute(doc, "aria-label") == ["A div"]
      assert attribute(doc, "class") == ["myclass"]
    end

    test "with boolean properties" do
      html =
        render_surface do
          ~F"""
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
          ~F"""
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

    test "shorthand notation `{...@attrs}`" do
      assigns = %{attrs: [class: "text-xs", style: "color: black;"]}

      html =
        render_surface do
          ~F"""
          <div {...@attrs}/>
          """
        end

      doc = parse_document!(html)

      assert attribute(doc, "class") == ["text-xs"]
      assert attribute(doc, "style") == ["color: black;"]
    end

    test "raise if trying to assisn `{... }` to an attribute" do
      assigns = %{attrs: %{}}

      code =
        quote do
          ~F"""
          <div
            class=
              {...@attrs} />
          """
        end

      message = ~r"""
      code:3:
      #{maybe_ansi("error:")} cannot assign `{\.\.\.@attrs}` to attribute `class`\. \
      The tagged expression `{\.\.\. }` can only be used on a root attribute/property\.

      Example: <div {\.\.\.@attrs}>
      """

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code, assigns)
      end)
    end
  end

  describe "modifiers" do
    test "using multiple modifiers" do
      assigns = %{items: [:a, :b]}

      html =
        render_surface do
          ~F"""
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
          ~F"""
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
          ~F"""
          <br/>
          <div :for.unknown={@items}>
            Index: {index}
          </div>
          """
        end

      message = ~r"""
      code:2:
      #{maybe_ansi("error:")} unknown modifier "unknown" for directive :for\
      """

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code, assigns)
      end)
    end

    test "raise compile error for modifiers with multiple clauses" do
      assigns = %{a: [1, 2], b: [1, 2]}

      code =
        quote do
          ~F"""
          <br/>
          <div :for.with_index={i <- a, j <- b}>
            Index: {index}
          </div>
          """
        end

      message = ~r"""
      code:2:
      #{maybe_ansi("error:")} cannot apply modifier "with_index" on generators with multiple clauses\
      """

      assert_raise(Surface.CompileError, message, fn ->
        compile_surface(code, assigns)
      end)
    end
  end

  describe ":for" do
    test "in components" do
      assigns = %{items: [1, 2]}

      html =
        render_surface do
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
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
          ~F"""
          <col :show={@show}>
          <col :show={true}>
          <col :show>
          """
        end

      assert html == """
             <col>
             <col>
             <col>
             """
    end

    test "when false, add hidden attribute" do
      assigns = %{show: false}

      html =
        render_surface do
          ~F"""
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
          ~F"""
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
          ~F"""
          <button :on-click={@click}>OK</button>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok", "target" => "#comp"}]]
    end

    test "as a string" do
      assigns = %{click: "ok"}

      html =
        render_surface do
          ~F"""
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
          ~F"""
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
          ~F"""
          <button :on-click={"ok", target: "#comp"}>OK</button>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok", "target" => "#comp"}]]
    end

    test "as %JS{} struct without target" do
      html =
        render_surface do
          ~F"""
          <button :on-click={JS.push("ok")}>OK</button>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok"}]]
    end

    test "as %JS{} struct with target" do
      html =
        render_surface do
          ~F"""
          <button :on-click={JS.push("ok", target: "#comp")}>OK</button>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok", "target" => "#comp"}]]
    end

    test "as %JS{} struct with target as :live_view" do
      html =
        render_surface do
          ~F"""
          <button :on-click={JS.push("ok", target: :live_view)}>OK</button>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok"}]]
    end

    defmodule LiveComponentUsingOnEvent do
      use Surface.LiveComponent

      def render(assigns), do: ~F[<button :on-click={JS.push("ok")}>OK</button>]
    end

    test "set the target of the %JS{} to @myself if it's a live_component and there's no target set yet" do
      html =
        render_surface do
          ~F"""
          <LiveComponentUsingOnEvent id="123"/>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok", "target" => 1}]]
    end

    defmodule LiveComponentUsingOnEventWithTarget do
      use Surface.LiveComponent

      def render(assigns), do: ~F[<button :on-click={JS.push("ok", target: "#comp")}>OK</button>]
    end

    test "don't set the target of the %JS{} if it's a live_component but there's already a target set" do
      html =
        render_surface do
          ~F"""
          <LiveComponentUsingOnEventWithTarget id="123"/>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "phx-click") == [["push", %{"event" => "ok", "target" => "#comp"}]]
    end

    defmodule FunctionComponentUsingOnEventInLivecomponent do
      use Surface.LiveComponent

      def render(assigns), do: ~F[<div><.func/></div>]
      def func(assigns), do: ~F[<button :on-click={JS.push("ok")}>OK</button>]
    end

    test "as %JS{} struct on a function component without target in a live component" do
      html =
        render_surface do
          ~F"""
          <FunctionComponentUsingOnEventInLivecomponent id="123"/>
          """
        end

      doc = parse_document!(html)

      assert js_attribute(doc, "div > button", "phx-click") == [["push", %{"event" => "ok"}]]
    end

    test "translate available events" do
      html =
        render_surface do
          ~F"""
          <div :on-click="event">click</div>
          <div :on-click-away="event">click-away</div>
          <div :on-capture-click="event">capture-click</div>
          <div :on-change="event">change</div>
          <div :on-submit="event">submit</div>
          <div :on-blur="event">blur</div>
          <div :on-focus="event">focus</div>
          <div :on-window-blur="event">window-blur</div>
          <div :on-window-focus="event">window-focus</div>
          <div :on-keydown="event">keydown</div>
          <div :on-keyup="event">keyup</div>
          <div :on-window-keydown="event">window-keydown</div>
          <div :on-window-keyup="event">window-keyup</div>
          <div :on-viewport-top="event">viewport-top</div>
          <div :on-viewport-bottom="event">viewport-bottom</div>
          """
        end

      assert html =~ """
             <div phx-click="event">click</div>
             <div phx-click-away="event">click-away</div>
             <div phx-capture-click="event">capture-click</div>
             <div phx-change="event">change</div>
             <div phx-submit="event">submit</div>
             <div phx-blur="event">blur</div>
             <div phx-focus="event">focus</div>
             <div phx-window-blur="event">window-blur</div>
             <div phx-window-focus="event">window-focus</div>
             <div phx-keydown="event">keydown</div>
             <div phx-keyup="event">keyup</div>
             <div phx-window-keydown="event">window-keydown</div>
             <div phx-window-keyup="event">window-keyup</div>
             <div phx-viewport-top="event">viewport-top</div>
             <div phx-viewport-bottom="event">viewport-bottom</div>
             """
    end

    test "do not translate invalid events" do
      html =
        render_surface do
          ~F"""
          <button :on-invalid="ok">OK</button>
          """
        end

      assert html =~ """
             <button :on-invalid="ok">OK</button>
             """
    end
  end

  describe ":hook" do
    test "generate a default phx-hook with __MODULE__ as default namespace" do
      html =
        render_surface do
          ~F"""
          <div :hook></div>
          """
        end

      assert html =~ """
             <div phx-hook="Surface.DirectivesTest#default"></div>
             """
    end

    test "generate phx-hook with __MODULE__ as default namespace" do
      html =
        render_surface do
          ~F"""
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
          ~F"""
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
          ~F"""
          <div :hook={nil}></div>
          """
        end

      assert html =~ """
             <div></div>
             """

      html =
        render_surface do
          ~F"""
          <div :hook={nil, from: Some.Fake.Comp}></div>
          """
        end

      assert html =~ """
             <div></div>
             """

      html =
        render_surface do
          ~F"""
          <div :hook={false}></div>
          """
        end

      assert html =~ """
             <div></div>
             """

      html =
        render_surface do
          ~F"""
          <div :hook={false, from: Some.Fake.Comp}></div>
          """
        end

      assert html =~ """
             <div></div>
             """
    end

    test "is compatible with other directives" do
      html =
        render_surface do
          ~F"""
          <div :hook="Button" :if={true}></div>
          """
        end

      assert html =~ """
             <div phx-hook="Surface.DirectivesTest#Button"></div>
             """

      html =
        render_surface do
          ~F"""
          <div :hook="Button" :for={_ <- [1]}></div>
          """
        end

      assert html =~ """
             <div phx-hook="Surface.DirectivesTest#Button"></div>
             """

      html =
        render_surface do
          ~F"""
          <div :hook="Button" :attrs={id: "myid"}></div>
          """
        end

      assert html =~ """
             <div phx-hook="Surface.DirectivesTest#Button" id="myid"></div>
             """

      html =
        render_surface do
          ~F"""
          <div :hook="Button" :show={false}></div>
          """
        end

      assert html =~ """
             <div phx-hook="Surface.DirectivesTest#Button" hidden></div>
             """

      html =
        render_surface do
          ~F"""
          <div :hook="Button" :on-click="click"></div>
          """
        end

      assert html =~ """
             <div phx-hook="Surface.DirectivesTest#Button" phx-click="click"></div>
             """
    end
  end

  describe ":values" do
    test "passing a keyword list" do
      html =
        render_surface do
          ~F"""
          <div :values={hello: :world, foo: "bar", one: 2, yes: true}>
            Some Text
          </div>
          """
        end

      doc = parse_document!(html)

      assert attribute(doc, "phx-value-foo") == ["bar"]
      assert attribute(doc, "phx-value-hello") == ["world"]
      assert attribute(doc, "phx-value-one") == ["2"]
      assert attribute(doc, "phx-value-yes") == ["true"]
    end

    test "passing a map" do
      html =
        render_surface do
          ~F"""
          <div :values={%{hello: :world, foo: "bar", one: 2, yes: true}}>
            Some Text
          </div>
          """
        end

      doc = parse_document!(html)

      assert attribute(doc, "phx-value-hello") == ["world"]
      assert attribute(doc, "phx-value-foo") == ["bar"]
      assert attribute(doc, "phx-value-one") == ["2"]
      assert attribute(doc, "phx-value-yes") == ["true"]
    end

    test "passing unsupported types" do
      assert_raise(Surface.CompileError, ~r(invalid value for key ":map" in attribute ":values".), fn ->
        """
        <div :values={map: %{}, tuple: {}}>
          Some Text
        </div>
        """
        |> Surface.Compiler.compile(1, __ENV__)
        |> Surface.Compiler.to_live_struct()
      end)
    end

    test "using an assign" do
      assigns = %{values: [hello: :world, foo: "bar", one: 2, yes: true]}

      html =
        render_surface do
          ~F"""
          <div :values={@values}>
            Some Text
          </div>
          """
        end

      doc = parse_document!(html)

      assert attribute(doc, "phx-value-hello") == ["world"]
      assert attribute(doc, "phx-value-foo") == ["bar"]
      assert attribute(doc, "phx-value-one") == ["2"]
      assert attribute(doc, "phx-value-yes") == ["true"]
    end

    test "static properties override dynamic properties" do
      html =
        render_surface do
          ~F"""
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

    test "with :if" do
      assigns = %{show: true}

      html =
        render_surface do
          ~F"""
          <div :if={@show} :values={foo: "bar"}>
            Show
          </div>
          """
        end

      assert html =~ """
             <div phx-value-foo=\"bar\">
               Show
             </div>
             """

      assigns = %{show: false}

      html =
        render_surface do
          ~F"""
          <div :if={@show} :values={foo: "bar"}>
            Show
          </div>
          """
        end

      assert html == "\n"
    end
  end

  test "on live components" do
    code = ~S'''
    defmodule Surface.DirectivesTest.OnLiveComponents do
      use Elixir.Surface.LiveComponent

      def render(assigns) do
        ~F"""
        <div>
          <div
            :attrs={a: 1}
            :on-click="fake"
            :show={false}
            :hook="fake"
            :values={a: 1}
            :if={true}
            :for={_i <- [1]}>
          </div>
        </div>
        """
      end
    end
    '''

    assert {{:module, _, _, _}, _} = Code.eval_string(code, [], %{__ENV__ | file: "code.exs", line: 1})
  end
end
