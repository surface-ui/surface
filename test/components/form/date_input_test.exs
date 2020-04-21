defmodule Surface.Components.Form.DateInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.DateInput, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <DateInput form="user" field="birthday" />
      """

      assert render_live(code) =~ """
             <input id="user_birthday" name="user[birthday]" type="date"/>
             """
    end

    test "setting the value" do
      code = """
      <DateInput form="user" field="birthday" value="mybirthday" />
      """

      assert render_live(code) =~ """
             <input id="user_birthday" name="user[birthday]" type="date" value="mybirthday"/>
             """
    end

    test "passing other options" do
      code = """
      <DateInput form="user" field="birthday" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[birthday]" type="date"/>
             """
    end
  end
end
