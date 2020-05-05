defmodule Surface.Components.Form.RadioButtonTest do
  use ExUnit.Case

  alias Surface.Components.Form.RadioButton, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "radio" do
      code = """
      <RadioButton form="user" field="role" value="admin"/>
      """

      assert render_live(code) =~ """
             <input id="user_role_admin" name="user[role]" type="radio" value="admin"/>
             """
    end

    test "passing other options" do
      code = """
      <RadioButton form="user" field="role" value="admin" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[role]" type="radio" value="admin"/>
             """
    end

    test "blur event with parent live view as target" do
      code = """
      <RadioButton form="user" field="role" value="admin" blur="my_blur" />
      """

      assert render_live(code) =~ """
             <input id="user_role_admin" name="user[role]" phx-blur="my_blur" type="radio" value="admin"/>
             """
    end

    test "focus event with parent live view as target" do
      code = """
      <RadioButton form="user" field="role" value="admin" focus="my_focus" />
      """

      assert render_live(code) =~ """
             <input id="user_role_admin" name="user[role]" phx-focus="my_focus" type="radio" value="admin"/>
             """
    end

    test "capture click event with parent live view as target" do
      code = """
      <RadioButton form="user" field="role" value="admin" capture_click="my_click" />
      """

      assert render_live(code) =~ """
             <input id="user_role_admin" name="user[role]" phx-capture-click="my_click" type="radio" value="admin"/>
             """
    end

    test "keydown event with parent live view as target" do
      code = """
      <RadioButton form="user" field="role" value="admin" keydown="my_keydown" />
      """

      assert render_live(code) =~ """
             <input id="user_role_admin" name="user[role]" phx-keydown="my_keydown" type="radio" value="admin"/>
             """
    end

    test "keyup event with parent live view as target" do
      code = """
      <RadioButton form="user" field="role" value="admin" keyup="my_keyup" />
      """

      assert render_live(code) =~ """
             <input id="user_role_admin" name="user[role]" phx-keyup="my_keyup" type="radio" value="admin"/>
             """
    end
  end
end
