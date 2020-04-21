defmodule Surface.Components.Form.EmailInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.EmailInput, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <EmailInput form="user" field="email" />
      """

      assert render_live(code) =~ """
             <input id="user_email" name="user[email]" type="email"/>
             """
    end

    test "setting the value" do
      code = """
      <EmailInput form="user" field="email" value="myemail" />
      """

      assert render_live(code) =~ """
             <input id="user_email" name="user[email]" type="email" value="myemail"/>
             """
    end

    test "passing other options" do
      code = """
      <EmailInput form="user" field="email" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[email]" type="email"/>
             """
    end
  end
end
