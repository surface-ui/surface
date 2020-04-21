defmodule Surface.Components.Form.TimeInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.TimeInput, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <TimeInput form="user" field="time" />
      """

      assert render_live(code) =~ """
             <input id="user_time" name="user[time]" type="time"/>
             """
    end

    test "setting the value" do
      code = """
      <TimeInput form="user" field="time" value="mytime" />
      """

      assert render_live(code) =~ """
             <input id="user_time" name="user[time]" type="time" value="mytime"/>
             """
    end

    test "passing other options" do
      code = """
      <TimeInput form="user" field="time" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[time]" type="time"/>
             """
    end
  end
end
