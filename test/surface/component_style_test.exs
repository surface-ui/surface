defmodule Surface.ComponentStyleTest do
  use Surface.ConnCase, async: true

  import Surface.Compiler.CSSTranslator,
    only: [
      scope_attr: 0,
      scope_attr: 1,
      scope_attr: 2,
      scope_id: 0,
      scope_id: 1,
      scope_id: 2,
      self_attr: 0,
      var_name: 2
    ]

  alias Mix.Tasks.Compile.SurfaceTest.FakeButton
  alias Mix.Tasks.Compile.SurfaceTest.FakeButtonWithVariant
  alias Mix.Tasks.Compile.SurfaceTest.MultipleStyles

  test "colocated css file" do
    html =
      render_surface do
        ~F"""
        <FakeButton/>
        """
      end

    color_var = var_name(scope_id(FakeButton), "@color")

    assert html =~ """
           <button style="#{color_var}: red" #{scope_attr(FakeButton)} class="btn">
             FAKE BUTTON
           </button>
           """
  end

  test "function component without inline styles gets the file's scope and no style vars" do
    html =
      render_surface do
        ~F"""
        <FakeButton.func_without_inline_style/>
        """
      end

    assert html =~ """
           <button #{scope_attr(FakeButton)} class="btn">
             FAKE BUTTON WITHOUT STYLE
           </button>
           """
  end

  test "the inline style is applied when both (inline and css file) are present" do
    html =
      render_surface do
        ~F"""
        <MultipleStyles/>
        """
      end

    assert html =~ """
           <div #{scope_attr(MultipleStyles, :render)} class="panel">
           FAKE PANEL
           </div>
           """
  end

  test "inline css style" do
    html =
      render_surface do
        ~F"""
        <style>
          .btn { padding: 10px; }
        </style>

        <button class="btn">OK</button>
        """
      end

    assert html =~ """
           <button #{scope_attr()} class="btn">OK</button>
           """
  end

  test "inline css style for function components" do
    html =
      render_surface do
        ~F"""
        <FakeButton.func/>
        """
      end

    padding_var = var_name(scope_id(FakeButton, :func), "@padding")
    color_var = var_name(scope_id(FakeButton, :func), "@color")

    assert html =~ """
           <button style="#{padding_var}: 10px; #{color_var}: red" #{scope_attr(FakeButton, :func)} class="btn-func">
             FAKE FUNCTION BUTTON
           </button>
           """
  end

  test "inject scope attribute when the element is present in the selectors" do
    html =
      render_surface do
        ~F"""
        <style>
          button { padding: 10px; }
          span { padding: 10px; }
        </style>

        <button>ok</button>
        <div>ok</div>
        <span>ok</span>
        """
      end

    assert html =~ """
           <button #{scope_attr()}>ok</button>
           <div>ok</div>
           <span #{scope_attr()}>ok</span>
           """
  end

  test "inject scope attribute when the class is present in the selectors" do
    html =
      render_surface do
        ~F"""
        <style>
          .btn1 { padding: 10px; }
          .btn2 { padding: 10px; }
        </style>

        <button class="btn1">ok</button>
        <button>ok</button>
        <button class="p-8 btn2">ok</button>
        """
      end

    assert html =~ """
           <button #{scope_attr()} class="btn1">ok</button>
           <button>ok</button>
           <button #{scope_attr()} class="p-8 btn2">ok</button>
           """
  end

  test "inject scope attribute in void elements" do
    html =
      render_surface do
        ~F"""
        <style>
          .input { padding: 10px; }
        </style>

        <input class="input"/>
        """
      end

    assert html =~ """
           <input #{scope_attr()} class="input">
           """
  end

  test "inject scope attribute when the id is present in the selectors" do
    html =
      render_surface do
        ~F"""
        <style>
          #btn1 { padding: 10px; }
          #btn2 { padding: 10px; }
        </style>

        <button id="btn1">ok</button>
        <button>ok</button>
        <button id="btn2">ok</button>
        """
      end

    assert html =~ """
           <button #{scope_attr()} id="btn1">ok</button>
           <button>ok</button>
           <button #{scope_attr()} id="btn2">ok</button>
           """
  end

  test "inject scope attribute in all elements if the universal selector `*` is present" do
    html =
      render_surface do
        ~F"""
        <style>
          * { padding: 10px; }
        </style>

        <div>ok</div>
        <span>ok</span>
        <button id="btn">ok</button>
        """
      end

    assert html =~ """
           <div #{scope_attr()}>ok</div>
           <span #{scope_attr()}>ok</span>
           <button #{scope_attr()} id="btn">ok</button>
           """
  end

  test "inject scope attribute in elements that match the element and class selector" do
    html =
      render_surface do
        ~F"""
        <style>
          div.panel { display: block }
        </style>

        <div>ok</div>
        <div class="panel">ok</div>
        <span class="panel">ok</span>
        """
      end

    assert html =~ """
           <div>ok</div>
           <div #{scope_attr()} class="panel">ok</div>
           <span class="panel">ok</span>
           """
  end

  test "inject scope attribute in elements that match the element and id selector" do
    html =
      render_surface do
        ~F"""
        <style>
          div#panel { display: block }
        </style>

        <div>ok</div>
        <div id="panel">ok</div>
        <span id="panel">ok</span>
        """
      end

    assert html =~ """
           <div>ok</div>
           <div #{scope_attr()} id="panel">ok</div>
           <span id="panel">ok</span>
           """
  end

  test "inject scope attribute in elements that match all classes" do
    html =
      render_surface do
        ~F"""
        <style>
          .a.b { display: block }
        </style>

        <div>ok</div>
        <div class="a">ok</div>
        <div class="b">ok</div>
        <div class="a b">ok</div>
        <span class="b a">ok</span>
        <span class="x a b y">ok</span>
        """
      end

    assert html =~ """
           <div>ok</div>
           <div class="a">ok</div>
           <div class="b">ok</div>
           <div #{scope_attr()} class="a b">ok</div>
           <span #{scope_attr()} class="b a">ok</span>
           <span #{scope_attr()} class="x a b y">ok</span>
           """
  end

  test "inject scope attribute on the root nodes if :deep is used at the begining" do
    html =
      render_surface do
        ~F"""
        <style>
          .main {
            @apply bg-blue-100;
          }

          :deep(.a) .link {
            @apply hover:underline;
          }
        </style>

        <div class="main">
          <div class="link">ok</div>
          <div class="a">ok</div>
        </div>
        <div class="a">ok</div>
        """
      end

    assert html =~ """
           <div #{self_attr()} #{scope_attr()} class="main">
             <div #{scope_attr()} class="link">ok</div>
             <div class="a">ok</div>
           </div>
           <div #{self_attr()} #{scope_attr()} class="a">ok</div>
           """
  end

  defmodule MyLink do
    use Surface.Component

    prop class, :css_class

    def render(assigns) do
      ~F"""
      <a href="#" class={"a"}>caller_scope_id: {@__caller_scope_id__}</a>
      """
    end
  end

  defmodule UsingMyLinkWithVariant do
    use Surface.Component

    prop live, :boolean, css_variant: true

    def render(assigns) do
      ~F"""
      <MyLink class="live:text-sm"/>
      """
    end
  end

  defmodule MyLinkNotUsingClass do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <a href="#">caller_scope_id: {@__caller_scope_id__}</a>
      """
    end
  end

  defmodule MyLinkOnlyDefiningClass do
    use Surface.Component

    prop class, :css_class

    def render(assigns) do
      ~F"""
      <a href="#">caller_scope_id: {@__caller_scope_id__}</a>
      """
    end
  end

  defmodule MyLinkOnlyPassingClassExpr do
    use Surface.Component

    def render(assigns) do
      ~F"""
      <a href="#" class={"a"}>caller_scope_id: {@__caller_scope_id__}</a>
      """
    end
  end

  test "don't inject caller's scope attribute if no style nor variants are defined" do
    html =
      render_surface do
        ~F"""
        <MyLink />
        """
      end

    assert html =~ """
           <a href="#" class="a">caller_scope_id: </a>
           """
  end

  test "inject caller's scope attribute if variants are defined" do
    html =
      render_surface do
        ~F"""
        <UsingMyLinkWithVariant/>
        """
      end

    assert html =~ """
           <a #{scope_attr(UsingMyLinkWithVariant)} href="#" class="a">caller_scope_id: #{scope_id(UsingMyLinkWithVariant)}</a>
           """
  end

  test "inject caller's scope attribute on the root nodes of a child components that define a :css_class prop and pass a class attr as expression" do
    html =
      render_surface do
        ~F"""
        <style>
        </style>
        <MyLink />
        <MyLinkNotUsingClass />
        <MyLinkOnlyDefiningClass />
        <MyLinkOnlyPassingClassExpr />
        """
      end

    assert html =~ """
           <a #{scope_attr()} href="#" class="a">caller_scope_id: #{scope_id()}</a>
           <a href="#">caller_scope_id: #{scope_id()}</a>
           <a href="#">caller_scope_id: #{scope_id()}</a>
           <a href="#" class="a">caller_scope_id: #{scope_id()}</a>
           """
  end

  test "inject caller's scope attribute without interfering with other dynamic props" do
    html =
      render_surface do
        ~F"""
        <style>
        </style>
        <MyLink {...class: "link"}/>
        """
      end

    assert html =~ """
           <a #{scope_attr()} href="#" class="a">caller_scope_id: #{scope_id()}</a>
           """
  end

  test "don't inject caller's scope attribute if the caller doesn't define styles" do
    html =
      render_surface do
        ~F"""
        <MyLink />
        """
      end

    assert html =~ """
           <a href="#" class="a">caller_scope_id: </a>
           """
  end

  defmodule LiveComponentWithUpdate do
    use Surface.LiveComponent

    prop class, :css_class

    @impl true
    def update(_assigns, socket) do
      {:ok, assign(socket, assigned_in_update: "Assigned in update/2")}
    end

    @impl true
    def render(assigns) do
      ~F"""
      <a href="#" class={"a"}>link</a>
      """
    end
  end

  defmodule ViewWithLiveComponentWithUpdate do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <style>
      </style>
      <LiveComponentWithUpdate id="comp" />
      """
    end
  end

  test "inject caller's scope attribute on live components implementing update/2, i.e. @__caller_scope_id__ is still there" do
    {:ok, _view, html} = live_isolated(build_conn(), ViewWithLiveComponentWithUpdate)

    attr = scope_attr(ViewWithLiveComponentWithUpdate, :render)

    # We need to use `attr="attr"` instead of just `attr` here because it seems live_isolated/2
    # renders attributes differently. Maybe because it relies on `<.dynamic_tag/>`?
    assert html =~ """
           <a data-phx-component=\"1\" #{attr}="#{attr}" href="#" class="a">link</a>\
           """
  end

  test "inject scope attribute in any element that matches any selector group. No matter if it doesn't match the whole selector" do
    html =
      render_surface do
        ~F"""
        <style>
          div.a.b:last-child > span.c.d { display: block }
        </style>

        <div>ok</div>
        <div class="a b">ok</div>
        <div class="c d">ok</div>
        <span class="a b">ok</span>
        <span class="c d">ok</span>
        """
      end

    assert html =~ """
           <div>ok</div>
           <div #{scope_attr()} class="a b">ok</div>
           <div class="c d">ok</div>
           <span class="a b">ok</span>
           <span #{scope_attr()} class="c d">ok</span>
           """
  end

  test "set the caller's scope attribute in elements passed using slots" do
    html =
      render_surface do
        ~F"""
        <FakeButton.outer_func/>
        """
      end

    assert html =~ """
           <button #{scope_attr(FakeButton, :outer_func)} #{scope_attr(FakeButton, :inner_func)} class="inner">
             <span #{scope_attr(FakeButton, :outer_func)} class="outer">Ok</span>
           </button>
           """
  end

  test "merge `style` variables when value is a literal string" do
    assigns = %{color: "red"}

    html =
      render_surface do
        ~F"""
        <style>
          .btn { color: s-bind('@color') }
        </style>

        <button class="btn" style="padding: 1px;">OK</button>
        """
      end

    color_var = var_name(scope_id(), "@color")

    assert html =~ ~s(style="padding: 1px; #{color_var}: red")
  end

  test "merge `style` variables when value is an expression" do
    assigns = %{color: "red"}

    html =
      render_surface do
        ~F"""
        <style>
          .btn { color: s-bind('@color') }
        </style>

        <button class="btn" style={padding: "1px"}>OK</button>
        """
      end

    color_var = var_name(scope_id(), "@color")

    assert html =~ ~s(style="padding: 1px; #{color_var}: red")
  end

  test "ignore white spaces before and after the <style> section" do
    html =
      render_surface do
        ~F"""


        <style>
          .btn { color: red }
        </style>


        <button class="btn">OK</button>
        """
      end

    assert html == """
           <button #{scope_attr()} class="btn">OK</button>
           """
  end

  test "if there are variants, add s-self, s-scope and data-[variant_name] to the root and s-scope to any children that may be using them" do
    html =
      render_surface do
        ~F"""
        <FakeButtonWithVariant visible={true} active={false} dark?={true}/>
        """
      end

    assert html =~ """
           <button data-dark data-visible data-other data-mapset data-keyword data-map data-items data-status="on" data-size="small" #{self_attr()} #{scope_attr(FakeButtonWithVariant)}>
             <span>no scope</span>
             <span class="class-not-using-variants">no scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@visible:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@not-visible:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@active:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@inactive:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@is-dark:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@is-light:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@size-small:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@on:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@off:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@has-items:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@no-items:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@has-map:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@no-map:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@has-keyword:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@no-keyword:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@has-mapset:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@no-mapset:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@valid:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@invalid:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@other:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="@no-other:block">with scope</span>
             <span #{scope_attr(FakeButtonWithVariant)} class="dynamic">with scope</span>
           </button>
           """
  end
end
