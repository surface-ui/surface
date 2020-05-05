defmodule Surface.Components.Form.ResetTest do
  use ExUnit.Case

  alias Surface.Components.Form.Reset, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty reset" do
      code = """
      <Reset />
      """

      assert render_live(code) =~ """
             <input type="reset" value="Reset"/>
             """
    end

    test "setting the value" do
      code = """
      <Reset value="ResetTheForm" />
      """

      assert render_live(code) =~ """
             <input type="reset" value="ResetTheForm"/>
             """
    end

    test "passing other options" do
      code = """
      <Reset opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" type="reset" value="Reset"/>
             """
    end

    test "blur event with parent live view as target" do
      code = """
      <Reset value="ResetTheForm" blur="my_blur" />
      """

      assert render_live(code) =~ """
             <input phx-blur="my_blur" type="reset" value="ResetTheForm"/>
             """
    end

    test "focus event with parent live view as target" do
      code = """
      <Reset value="ResetTheForm" focus="my_focus" />
      """

      assert render_live(code) =~ """
             <input phx-focus="my_focus" type="reset" value="ResetTheForm"/>
             """
    end

    test "capture click event with parent live view as target" do
      code = """
      <Reset value="ResetTheForm" capture_click="my_click" />
      """

      assert render_live(code) =~ """
             <input phx-capture-click="my_click" type="reset" value="ResetTheForm"/>
             """
    end

    test "keydown event with parent live view as target" do
      code = """
      <Reset value="ResetTheForm" keydown="my_keydown" />
      """

      assert render_live(code) =~ """
             <input phx-keydown="my_keydown" type="reset" value="ResetTheForm"/>
             """
    end

    test "keyup event with parent live view as target" do
      code = """
      <Reset value="ResetTheForm" keyup="my_keyup" />
      """

      assert render_live(code) =~ """
             <input phx-keyup="my_keyup" type="reset" value="ResetTheForm"/>
             """
    end
  end
end
