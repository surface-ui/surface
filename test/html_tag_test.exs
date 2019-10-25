defmodule HtmlTagTest do
  use ExUnit.Case
  import ComponentTestHelper
  import Surface.Component
  import Surface.Properties

  test "css class with keyword list notation" do
    assigns = %{value1: true, value2: false, value3: true}
    code =
      ~H"""
      <div class={{ "default1", "default2", prop1: @value1, prop2: @value2, prop3: @value3 }}/>
      """

    assert render_surface(code) =~ """
    <div class="default1 default2 prop1 prop3"/>
    """
  end
end
