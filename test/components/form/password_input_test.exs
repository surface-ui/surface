defmodule Surface.Components.Form.PasswordInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.PasswordInput, warn: false

  import ComponentTestHelper

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
      <PasswordInput form="user" field="password" value="mypassword" />
      """

      assert render_live(code) =~ """
             <input id="user_password" name="user[password]" type="password" value="mypassword"/>
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
  end
end
