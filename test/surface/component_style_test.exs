defmodule Surface.ComponentStyleTest do
  use Surface.ConnCase, async: true

  alias Mix.Tasks.Compile.SurfaceTest.FakeButton

  test "colocated css file" do
    html =
      render_surface do
        ~F"""
        <FakeButton/>
        """
      end

    assert html =~ """
           <button style="--59c08eb: red" data-s-8c9b2e4 class="btn">
             FAKE BUTTON
           </button>
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
           <button data-s-1bd4222 class="btn">OK</button>
           """
  end

  test "inline css style for function components" do
    html =
      render_surface do
        ~F"""
        <FakeButton.func/>
        """
      end

    assert html =~ """
           <button style="--81d9fb2: 10px; --e2913a0: red" data-s-580c948 class="btn-func">
             FAKE FUNCTION BUTTON
           </button>
           """
  end

  test "inject s-data-* when the element is present in the selectors" do
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
           <button data-s-05ec951>ok</button>
           <div>ok</div>
           <span data-s-05ec951>ok</span>
           """
  end

  test "inject s-data-* when the class is present in the selectors" do
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
           <button data-s-597e148 class="btn1">ok</button>
           <button>ok</button>
           <button data-s-597e148 class="p-8 btn2">ok</button>
           """
  end

  test "inject s-data-* in void elements" do
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
           <input data-s-ec11bd3 class="input">
           """
  end

  test "inject s-data-* when the id is present in the selectors" do
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
           <button data-s-b461126 id="btn1">ok</button>
           <button>ok</button>
           <button data-s-b461126 id="btn2">ok</button>
           """
  end

  test "inject s-data-* in all elements if the universal selector `*` is present" do
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
           <div data-s-b0be4f9>ok</div>
           <span data-s-b0be4f9>ok</span>
           <button data-s-b0be4f9 id="btn">ok</button>
           """
  end

  test "inject s-data-* in elements that match the element and class selector" do
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
           <div data-s-a6137cb class="panel">ok</div>
           <span class="panel">ok</span>
           """
  end

  test "inject s-data-* in elements that match the element and id selector" do
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
           <div data-s-79e87d1 id="panel">ok</div>
           <span id="panel">ok</span>
           """
  end

  test "inject s-data-* in elements that match all classes" do
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
           <div data-s-9651d1c class="a b">ok</div>
           <span data-s-9651d1c class="b a">ok</span>
           <span data-s-9651d1c class="x a b y">ok</span>
           """
  end

  test "inject s-data-* on the root node if :deep is used at the begining" do
    html =
      render_surface do
        ~F"""
        <style>
          :deep(a) .link {
            @apply hover:underline;
          }
        </style>

        <div>
          <div class="link">ok</div>
        </div>
        <div class="a">ok</div>
        """
      end

    assert html =~ """
           <div data-s-self data-s-03cb861>
             <div data-s-03cb861 class="link">ok</div>
           </div>
           <div data-s-self data-s-03cb861 class="a">ok</div>
           """
  end

  test "inject s-data-* in any element that matches any selector group. No matter if it doesn't match the whole selector" do
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
           <div data-s-77c06c9 class="a b">ok</div>
           <div class="c d">ok</div>
           <span class="a b">ok</span>
           <span data-s-77c06c9 class="c d">ok</span>
           """
  end

  test "set the caller's scope id to s-data-* in elements passed using slots" do
    html =
      render_surface do
        ~F"""
        <FakeButton.outer_func/>
        """
      end

    style = FakeButton.__style__()
    assert style[:outer_func].scope_id == "1a5377d"
    assert style[:inner_func].scope_id == "bd41653"

    assert html =~ """
           <button data-s-bd41653 class="inner">
             <span data-s-1a5377d class="outer">Ok</span>
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

    assert html =~ ~S(style="padding: 1px; --bfe9859: red")
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

    assert html =~ ~S(style="padding: 1px; --b9c15f4: red")
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
           <button data-s-d121568 class="btn">OK</button>
           """
  end
end
