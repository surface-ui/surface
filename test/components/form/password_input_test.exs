defmodule Surface.Components.Form.PasswordInputTest do
  use ExUnit.Case

  import ComponentTestHelper

  alias Surface.Components.Form.PasswordInput, warn: false

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <PasswordInput form="user" field="password" />
      """

      assert render_live(code) =~ """
             <input id="user_password" name="user[password]" type="password"/>
             """
    end

    test "setting the value" do
      code = """
      <PasswordInput form="user" field="password" value="secret" />
      """

      assert render_live(code) =~ """
             <input id="user_password" name="user[password]" type="password" value="secret"/>
             """
    end

    test "passing other options" do
      code = """
      <PasswordInput form="user" field="password" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[password]" type="password"/>
             """
    end

    test "blur event with parent live view as target" do
      code = """
      <PasswordInput form="user" field="color" value="secret" blur="my_blur" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-blur="my_blur" type="password" value="secret"/>
             """
    end

    test "focus event with parent live view as target" do
      code = """
      <PasswordInput form="user" field="color" value="secret" focus="my_focus" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-focus="my_focus" type="password" value="secret"/>
             """
    end

    test "capture click event with parent live view as target" do
      code = """
      <PasswordInput form="user" field="color" value="secret" capture_click="my_click" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-capture-click="my_click" type="password" value="secret"/>
             """
    end

    test "keydown event with parent live view as target" do
      code = """
      <PasswordInput form="user" field="color" value="secret" keydown="my_keydown" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="password" value="secret"/>
             """
    end

    test "keyup event with parent live view as target" do
      code = """
      <PasswordInput form="user" field="color" value="secret" keyup="my_keyup" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="password" value="secret"/>
             """
    end
  end
end
