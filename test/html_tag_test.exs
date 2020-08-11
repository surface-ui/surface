defmodule HtmlTagTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper

  test "raise runtime error for invalid attributes values" do
    assert_raise(RuntimeError, ~r/invalid value for attribute "title"/, fn ->
      assigns = %{}

      code = ~H"""
      <div title={{ {1, 2} }}/>
      """

      render_static(code)
    end)
  end

  describe "basic attibutes" do
    test "as string" do
      assigns = %{}

      code = ~H"""
      <div title="My title"/>
      """

      assert render_static(code) =~ """
             <div title="My title"></div>
             """
    end

    test "without a value" do
      assigns = %{}

      code = ~H"""
      <div data-option-is-present />
      """

      assert render_static(code) =~ """
             <div data-option-is-present></div>
             """
    end

    test "as expression" do
      assigns = %{title: "My title"}

      code = ~H"""
      <div title={{ @title }}/>
      """

      assert render_static(code) =~ """
             <div title="My title"></div>
             """
    end

    test "as string with interpolation" do
      assigns = %{title: "title"}

      code = ~H"""
      <div title="My {{ @title }}"/>
      """

      assert render_static(code) =~ """
             <div title="My title"></div>
             """
    end

    test "with `@` and `.`" do
      assigns = %{}

      code = ~H"""
      <div @click.away="open = false"/>
      """

      assert render_static(code) =~ """
             <div @click.away="open = false"></div>
             """
    end

    test "with utf-8 attribute value" do
      assigns = %{}

      code = ~H"""
      <div title="héllo"/>
      """

      assert render_static(code) =~ """
             <div title="héllo"></div>
             """
    end

    test "with utf-8 expression attribute value" do
      assigns = %{}

      code = ~H"""
      <div title={{ "héllo" }}/>
      """

      assert render_static(code) =~ """
             <div title="héllo"></div>
             """
    end

    test "with nil parameter" do
      assigns = %{nilvalue: nil}

      code = ~H"""
      <div nilvalue={{ @nilvalue }}/>
      """

      assert render_static(code) =~ """
             <div></div>
             """
    end

    test "with nil value" do
      assigns = %{}

      code = ~H"""
      <div nilvalue={{ nil }}/>
      """

      assert render_static(code) =~ """
             <div></div>
             """
    end

    test "with phx-event nil parameter" do
      assigns = %{nilvalue: nil}

      code = ~H"""
      <div phx-click={{ @nilvalue }}/>
      """

      assert render_static(code) =~ """
             <div></div>
             """
    end
  end

  describe "css class attributes" do
    test "as string" do
      assigns = %{value1: true, value2: false, value3: true}

      code = ~H"""
      <div class="myclass"/>
      """

      assert render_static(code) =~ """
             <div class="myclass"></div>
             """
    end

    test "css class with keyword list notation" do
      assigns = %{value1: true, value2: false, value3: true}

      code = ~H"""
      <div class={{ "default1", "default2", prop1: @value1, prop2: @value2, prop3: @value3 }}/>
      """

      assert render_static(code) =~ """
             <div class="default1 default2 prop1 prop3"></div>
             """
    end

    test "css class with periods in names" do
      assigns = %{value1: true, value2: false, value3: true}

      code = ~H"""
      <div class={{ "default.1", "default.2", "prop.1": @value1, prop2: @value2, prop3: @value3 }}/>
      """

      assert render_static(code) =~ """
             <div class="default.1 default.2 prop.1 prop3"></div>
             """
    end

    test "css class with underscores in names" do
      assigns = %{value1: true, value2: false, value3: true}

      code = ~H"""
      <div class={{ "default__1", "default__2", prop__1: @value1, prop2: @value2, prop3: @value3 }}/>
      """

      assert render_static(code) =~ """
             <div class="default__1 default__2 prop__1 prop3"></div>
             """
    end

    test "css class defined with an atom" do
      assigns = %{}

      code = ~H"""
      <div class={{:default}}/>
      """

      assert render_static(code) =~ """
             <div class="default"></div>
             """
    end

    test "css class with uppercase letter" do
      assigns = %{value1: true}

      code = ~H"""
      <div class={{ "Default", Prop1: @value1 }}/>
      """

      assert render_static(code) =~ """
             <div class="Default Prop1"></div>
             """
    end
  end

  test "boolean attributes" do
    assigns = %{checked: true, focus: false}

    code = ~H"""
    <input
      disabled={{ false }}
      checked={{ @checked }}
      autofocus={{ @focus == true }}
      readonly="false"
      default={{ true }}
      required={{ nil }}
    />
    """

    assert render_static(code) =~ """
           <input checked readonly default>
           """
  end

  describe "style attibute" do
    test "as string" do
      assigns = %{}

      code = ~H"""
      <div style="height: 10px;"/>
      """

      assert render_static(code) =~ """
             <div style="height: 10px;"></div>
             """
    end

    test "as expression" do
      assigns = %{}

      code = ~H"""
      <div style={{ "height: 10px;" }}/>
      """

      assert render_static(code) =~ """
             <div style="height: 10px;"></div>
             """
    end

    test "as string with interpolation" do
      assigns = %{height: 10}

      code = ~H"""
      <div style="height: {{ @height }}px;"/>
      """

      assert render_static(code) =~ """
             <div style="height: 10px;"></div>
             """
    end

    test "raise runtime error for invalid style value" do
      assert_raise(RuntimeError, ~r/invalid value for attribute "style"/, fn ->
        assigns = %{}

        code = ~H"""
        <div style={{ {1, 2} }}/>
        """

        render_static(code)
      end)
    end
  end
end
