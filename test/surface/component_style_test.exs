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
           <button style="--c57608f--color: red" data-s-2a98af4 class="btn">
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
           <button data-s-628eb64 class="btn">OK</button>
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
           <button data-s-628eb64>ok</button>
           <div>ok</div>
           <span data-s-628eb64>ok</span>
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
           <button data-s-628eb64 class="btn1">ok</button>
           <button>ok</button>
           <button data-s-628eb64 class="p-8 btn2">ok</button>
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
           <button data-s-628eb64 id="btn1">ok</button>
           <button>ok</button>
           <button data-s-628eb64 id="btn2">ok</button>
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
           <div data-s-628eb64>ok</div>
           <span data-s-628eb64>ok</span>
           <button data-s-628eb64 id="btn">ok</button>
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
           <div data-s-628eb64 class="panel">ok</div>
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
           <div data-s-628eb64 id="panel">ok</div>
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
           <div data-s-628eb64 class="a b">ok</div>
           <span data-s-628eb64 class="b a">ok</span>
           <span data-s-628eb64 class="x a b y">ok</span>
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
           <div data-s-628eb64 class="a b">ok</div>
           <div class="c d">ok</div>
           <span class="a b">ok</span>
           <span data-s-628eb64 class="c d">ok</span>
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

    assert html =~ ~S(style="padding: 1px; --25b4204--color: red")
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

    assert html =~ ~S(style="padding: 1px; --25b4204--color: red")
  end
end
