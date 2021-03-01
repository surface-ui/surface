defmodule HtmlTagTest do
  use Surface.ConnCase, async: true

  @encoded_json "[{\"x\":10,\"y\":20}]"

  test "raise runtime error for invalid attributes values" do
    assert_raise(RuntimeError, ~r/invalid value for attribute "title"/, fn ->
      render_surface do
        ~H"""
        <div title={{ {1, 2} }}/>
        """
      end
    end)
  end

  describe "escape HTML when interpolating" do
    test "inside the body" do
      assigns = %{value: @encoded_json}

      html =
        render_surface do
          ~H"""
          <div>
          {{ @value }}
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
          ~H"""
          <div data-value={{ @value }}/>
          """
        end

      assert html =~ """
             <div data-value="[{&quot;x&quot;:10,&quot;y&quot;:20}]"></div>
             """
    end

    test "inside string attributes" do
      assigns = %{value: @encoded_json}

      html =
        render_surface do
          ~H"""
          <div data-value="Value: {{ @value }}"/>
          """
        end

      assert html =~ """
             <div data-value="Value: [{&quot;x&quot;:10,&quot;y&quot;:20}]"></div>
             """
    end
  end

  describe "don't escape HTML when interpolating safe values" do
    test "inside the body" do
      assigns = %{value: @encoded_json}

      html =
        render_surface do
          ~H"""
          <div>
          {{ {:safe, @value} }}
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
          ~H"""
          <div data-value={{ {:safe, @value} }}/>
          """
        end

      assert html =~ """
             <div data-value="[{"x":10,"y":20}]"></div>
             """
    end

    test "raise error if inside string attributes" do
      assert_raise(Protocol.UndefinedError, ~r/protocol String.Chars not implemented/, fn ->
        assigns = %{value: @encoded_json}

        render_surface do
          ~H"""
          <div data-value="Value: {{ {:safe, @value} }}"/>
          """
        end
      end)
    end
  end

  describe "basic attibutes" do
    test "as string" do
      html =
        render_surface do
          ~H"""
          <div title="My title"/>
          """
        end

      assert html =~ """
             <div title="My title"></div>
             """
    end

    test "without a value" do
      html =
        render_surface do
          ~H"""
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
          ~H"""
          <div title={{ @title }}/>
          """
        end

      assert html =~ """
             <div title="My title"></div>
             """
    end

    test "as string with interpolation" do
      assigns = %{title: "title"}

      html =
        render_surface do
          ~H"""
          <div title="My {{ @title }}"/>
          """
        end

      assert html =~ """
             <div title="My title"></div>
             """
    end

    test "with `@`, `:`, `_` as first char" do
      html =
        render_surface do
          ~H"""
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
          ~H"""
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
          ~H"""
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
          ~H"""
          <div title={{ "héllo" }}/>
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
          ~H"""
          <div nilvalue={{ @nilvalue }}/>
          """
        end

      assert html =~ """
             <div></div>
             """
    end

    test "with nil value" do
      html =
        render_surface do
          ~H"""
          <div nilvalue={{ nil }}/>
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
          ~H"""
          <div phx-click={{ @nilvalue }}/>
          """
        end

      assert html =~ """
             <div></div>
             """
    end
  end

  describe "css class attributes" do
    test "as string" do
      assigns = %{value1: true, value2: false, value3: true}

      html =
        render_surface do
          ~H"""
          <div class="myclass"/>
          """
        end

      assert html =~ """
             <div class="myclass"></div>
             """
    end

    test "css class with keyword list notation" do
      assigns = %{value1: true, value2: false, value3: "red", value4: "rounded"}

      html =
        render_surface do
          ~H"""
          <div class={{ "default1", "default2", prop1: @value1, prop2: @value2, "is-#{@value3}": @value3, "is-#{@value4}": @value4 }}/>
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
          ~H"""
          <div class={{ "default.1", "default.2", "prop.1": @value1, prop2: @value2, prop3: @value3 }}/>
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
          ~H"""
          <div class={{ "default__1", "default__2", prop__1: @value1, prop2: @value2, prop3: @value3 }}/>
          """
        end

      assert html =~ """
             <div class="default__1 default__2 prop__1 prop3"></div>
             """
    end

    test "css class defined with an atom" do
      html =
        render_surface do
          ~H"""
          <div class={{:default}}/>
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
          ~H"""
          <div class={{ "Default", Prop1: @value1 }}/>
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
          ~H"""
          <div class={{ @value1 }}/>
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
        ~H"""
        <input
          disabled={{ false }}
          checked={{ @checked }}
          autofocus={{ @focus == true }}
          readonly="false"
          default={{ true }}
          required={{ nil }}
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
          ~H"""
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
          ~H"""
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
          ~H"""
          <div style={{ "height: 10px;" }}/>
          """
        end

      assert html =~ """
             <div style="height: 10px"></div>
             """
    end

    test "as string with interpolation" do
      assigns = %{height: 10}

      html =
        render_surface do
          ~H"""
          <div style="height: {{ @height }}px;"/>
          """
        end

      assert html =~ """
             <div style="height: 10px"></div>
             """
    end

    test "raise runtime error for invalid style value" do
      assert_raise(RuntimeError, ~r/invalid value for attribute "style"/, fn ->
        render_surface do
          ~H"""
          <div style={{ {1, 2} }}/>
          """
        end
      end)
    end
  end
end
