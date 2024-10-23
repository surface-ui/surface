defmodule HtmlTagTest do
  use Surface.ConnCase, async: true

  @encoded_json "[{\"x\":10,\"y\":20}]"

  alias Phoenix.LiveView.Rendered

  defp eval(string, caller, assigns \\ %{}) do
    string
    |> Surface.Compiler.compile(1, caller)
    |> Surface.Compiler.to_live_struct()
    |> Code.eval_quoted(assigns: assigns)
    |> elem(0)
  end

  test "raise runtime error for invalid attributes values" do
    assert_raise(Surface.CompileError, ~r/invalid value for attribute "title"/, fn ->
      "<div title={{1, 2}}/>"
      |> Surface.Compiler.compile(1, __ENV__)
      |> Surface.Compiler.to_live_struct()
    end)
  end

  test "dynamic attribute names in camel_case should be translated to snake-case" do
    expected = ~S(<button phx-value-my-value="foo"></button>)

    html = render_surface(do: ~F[<button {... phx_value_my_value: String.downcase("FOO")}/>])
    assert html =~ expected

    html = render_surface(do: ~F[<button {... phx_value_my_value: "foo"}/>])
    assert html =~ expected
  end

  test "literal attribute names in camel_case should not be translated to snake-case" do
    expected = ~S(<button phx-value-my_value="foo"></button>)

    html = render_surface(do: ~F[<button phx-value-my_value="foo"/>])
    assert html =~ expected

    html = render_surface(do: ~F[<button phx-value-my_value={"foo"}/>])
    assert html =~ expected

    html = render_surface(do: ~F[<button phx-value-my_value={String.downcase("FOO")}/>])
    assert html =~ expected
  end

  describe "escape HTML when interpolating" do
    test "inside the body" do
      assigns = %{value: @encoded_json}

      html =
        render_surface do
          ~F"""
          <div>
          {@value}
          </div>
          """
        end

      assert html =~ """
             <div>
             [{&quot;x&quot;:10,&quot;y&quot;:20}]
             </div>
             """
    end

    test "as attribute values" do
      assigns = %{value: @encoded_json}

      html =
        render_surface do
          ~F"""
          <div data-value={@value}/>
          """
        end

      assert html =~ """
             <div data-value="[{&quot;x&quot;:10,&quot;y&quot;:20}]"></div>
             """
    end
  end

  describe "don't escape HTML when interpolating safe values" do
    test "inside the body" do
      assigns = %{value: @encoded_json}

      html =
        render_surface do
          ~F"""
          <div>
          {{:safe, @value}}
          </div>
          """
        end

      assert html =~ """
             <div>
             [{"x":10,"y":20}]
             </div>
             """
    end

    test "as attribute values" do
      assigns = %{value: @encoded_json}

      html =
        render_surface do
          ~F"""
          <div data-value={{:safe, @value}}/>
          """
        end

      assert html =~ """
             <div data-value="[{"x":10,"y":20}]"></div>
             """
    end
  end

  describe "basic attributes" do
    test "as literal string" do
      html =
        render_surface do
          ~F"""
          <div title="My title"/>
          """
        end

      assert html =~ """
             <div title="My title"></div>
             """
    end

    test "as literal string don't encode HTML entities" do
      html =
        render_surface do
          ~F"""
          <div title="1 < 2"/>
          """
        end

      assert html =~ """
             <div title="1 < 2"></div>
             """
    end

    test "as expression with a literal string, encode HTML entities" do
      html =
        render_surface do
          ~F"""
          <div title={"> 123"}/>
          """
        end

      assert html =~ """
             <div title="&gt; 123"></div>
             """
    end

    test "without a value" do
      html =
        render_surface do
          ~F"""
          <div data-option-is-present />
          """
        end

      assert html =~ """
             <div data-option-is-present></div>
             """
    end

    test "as expression" do
      assigns = %{title: "My title"}

      html =
        render_surface do
          ~F"""
          <div title={@title}/>
          """
        end

      assert html =~ """
             <div title="My title"></div>
             """
    end

    test "with `@`, `:`, `_` as first char" do
      html =
        render_surface do
          ~F"""
          <div click?="open = true" @click="open = true" :click="open = true" />
          """
        end

      assert html =~ """
             <div click?="open = true" @click="open = true" :click="open = true"></div>
             """
    end

    test "with `@` and `.`" do
      html =
        render_surface do
          ~F"""
          <div @click.away="open = false"/>
          """
        end

      assert html =~ """
             <div @click.away="open = false"></div>
             """
    end

    test "with utf-8 attribute value" do
      html =
        render_surface do
          ~F"""
          <div title="héllo"/>
          """
        end

      assert html =~ """
             <div title="héllo"></div>
             """
    end

    test "with utf-8 expression attribute value" do
      html =
        render_surface do
          ~F"""
          <div title={"héllo"}/>
          """
        end

      assert html =~ """
             <div title="héllo"></div>
             """
    end

    test "with nil parameter" do
      assigns = %{nilvalue: nil}

      html =
        render_surface do
          ~F"""
          <div nilvalue={@nilvalue}/>
          """
        end

      assert html =~ """
             <div></div>
             """
    end

    test "with nil value" do
      html =
        render_surface do
          ~F"""
          <div nilvalue={nil}/>
          """
        end

      assert html =~ """
             <div></div>
             """
    end

    test "with phx-event nil parameter" do
      assigns = %{nilvalue: nil}

      html =
        render_surface do
          ~F"""
          <div phx-click={@nilvalue}/>
          """
        end

      assert html =~ """
             <div></div>
             """
    end
  end

  describe "css class attributes" do
    test "as string literal" do
      assigns = %{value1: true, value2: false, value3: true}

      html =
        render_surface do
          ~F"""
          <div class="myclass"/>
          """
        end

      assert html =~ """
             <div class="myclass"></div>
             """
    end

    test "as string literal, translate directly to static html, without encoding" do
      %Rendered{static: static} = eval(~S{<div class="[&:nth-child(2)]:p-4"></div>}, __ENV__)

      assert static == [~S{<div class="[&:nth-child(2)]:p-4"></div>}]
    end

    test "as expression with a literal string, translate and encode directly to static html" do
      code = """
      <div class={"[&:nth-child(2)]:p-4"}/>\
      """

      %Rendered{static: static} = eval(code, __ENV__)

      assert static == [~S{<div class="[&amp;:nth-child(2)]:p-4"></div>}]
    end

    test "css class with keyword list notation" do
      assigns = %{value1: true, value2: false, value3: "red", value4: "rounded"}

      html =
        render_surface do
          ~F"""
          <div class={"default1", "default2", prop1: @value1, prop2: @value2, "is-#{@value3}": @value3, "is-#{@value4}": @value4}/>
          """
        end

      assert html =~ """
             <div class="default1 default2 prop1 is-red is-rounded"></div>
             """
    end

    test "css class with periods in names" do
      assigns = %{value1: true, value2: false, value3: true}

      html =
        render_surface do
          ~F"""
          <div class={"default.1", "default.2", "prop.1": @value1, prop2: @value2, prop3: @value3}/>
          """
        end

      assert html =~ """
             <div class="default.1 default.2 prop.1 prop3"></div>
             """
    end

    test "css class with underscores in names" do
      assigns = %{value1: true, value2: false, value3: true}

      html =
        render_surface do
          ~F"""
          <div class={"default__1", "default__2", prop__1: @value1, prop2: @value2, prop3: @value3}/>
          """
        end

      assert html =~ """
             <div class="default__1 default__2 prop__1 prop3"></div>
             """
    end

    test "css class defined with an atom" do
      html =
        render_surface do
          ~F"""
          <div class={:default}/>
          """
        end

      assert html =~ """
             <div class="default"></div>
             """
    end

    test "css class with uppercase letter" do
      assigns = %{value1: true}

      html =
        render_surface do
          ~F"""
          <div class={"Default", Prop1: @value1}/>
          """
        end

      assert html =~ """
             <div class="Default Prop1"></div>
             """
    end

    test "don't render attribute if value is nil" do
      assigns = %{value1: nil}

      html =
        render_surface do
          ~F"""
          <div class={@value1}/>
          """
        end

      assert html =~ """
             <div></div>
             """
    end
  end

  test "boolean attributes" do
    assigns = %{checked: true, focus: false}

    html =
      render_surface do
        ~F"""
        <input
          disabled={false}
          checked={@checked}
          autofocus={@focus == true}
          readonly="false"
          default={true}
          required={nil}
        />
        """
      end

    assert html =~ """
           <input checked readonly default>
           """
  end

  describe "style attribute" do
    test "as string" do
      html =
        render_surface do
          ~F"""
          <div style="height: 10px;"/>
          """
        end

      assert html =~ """
             <div style="height: 10px"></div>
             """
    end

    test "as string containing `:` in the value" do
      html =
        render_surface do
          ~F"""
          <div style="background-image: url(https://example.com/breaks.jpg)"/>
          """
        end

      assert html =~ """
             <div style="background-image: url(https://example.com/breaks.jpg)"></div>
             """
    end

    test "as expression" do
      html =
        render_surface do
          ~F"""
          <div style={"height: 10px;"}/>
          """
        end

      assert html =~ """
             <div style="height: 10px"></div>
             """
    end

    test "raise compile error for invalid style value that can be evaluated at compile time" do
      assert_raise(Surface.CompileError, ~r/invalid value for attribute "style"/, fn ->
        "<div style={{1, 2}}/>"
        |> Surface.Compiler.compile(1, __ENV__)
        |> Surface.Compiler.to_live_struct()
      end)
    end

    test "raise runtime error for invalid style value" do
      assert_raise(RuntimeError, ~r/invalid value for attribute "style"/, fn ->
        assigns = %{style: {1, 2}}

        render_surface do
          ~F"""
          <div style={@style}/>
          """
        end
      end)
    end
  end
end
