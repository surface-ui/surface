defmodule Surface.Components.Form.TextInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.TextInput

  import Surface
  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <TextInput form="user" field="name" />
      """

      assert render_live(code) =~ """
             <input id="user_name" name="user[name]" type="text" value=""/>
             """
    end

    test "setting the value" do
      code = """
      <TextInput form="user" field="name" value="myname" />
      """

      assert render_live(code) =~ """
             <input id="user_name" name="user[name]" type="text" value="myname"/>
             """
    end

    test "passing other options" do
      code = """
      <TextInput form="user" field="name" opts={{ [id: "myid", autofocus: "autofocus"] }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[name]" type="text" value=""/>
             """
    end
  end
end
