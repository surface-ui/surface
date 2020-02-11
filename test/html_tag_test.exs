defmodule HtmlTagTest do
  use ExUnit.Case

  import Surface
  import ComponentTestHelper

  test "css class with keyword list notation" do
    assigns = %{value1: true, value2: false, value3: true}
    code =
      ~H"""
      <div class={{ "default1", "default2", prop1: @value1, prop2: @value2, prop3: @value3 }}/>
      """

    assert render_static(code) =~ """
    <div class="default1 default2 prop1 prop3"></div>
    """
  end

  test "boolean attributes" do
    assigns = %{checked: true, focus: false}
    code =
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

    assert render_static(code) =~ """
    <input\n  \n  checked\n  \n  readonly=\"false\"\n  default\n  \n>
    """
  end

  test "raise runtime error for invalid attributes values" do
    assert_raise(RuntimeError, ~r/invalid value for attribute "label"/, fn ->
      assigns = %{}
      ~H"""
      <div label={{ {1, 2} }}/>
      """
    end)
  end

  test "raise runtime error for invalid style value" do
    assert_raise(RuntimeError, ~r/invalid value for attribute "style"/, fn ->
      assigns = %{}
      ~H"""
      <div style={{ {1, 2} }}/>
      """
    end)
  end
end
