defmodule Surface.Components.Form.TimeInputTest do
  use ExUnit.Case

  import ComponentTestHelper

  alias Surface.Components.Form.TimeInput, warn: false

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
      <TimeInput form="user" field="time" value="23:59:59" />
      """

      assert render_live(code) =~ """
             <input id="user_time" name="user[time]" type="time" value="23:59:59"/>
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

    test "blur event with parent live view as target" do
      code = """
      <TimeInput form="user" field="color" value="23:59:59" blur="my_blur" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-blur="my_blur" type="time" value="23:59:59"/>
             """
    end

    test "focus event with parent live view as target" do
      code = """
      <TimeInput form="user" field="color" value="23:59:59" focus="my_focus" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-focus="my_focus" type="time" value="23:59:59"/>
             """
    end

    test "capture click event with parent live view as target" do
      code = """
      <TimeInput form="user" field="color" value="23:59:59" capture_click="my_click" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-capture-click="my_click" type="time" value="23:59:59"/>
             """
    end

    test "keydown event with parent live view as target" do
      code = """
      <TimeInput form="user" field="color" value="23:59:59" keydown="my_keydown" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="time" value="23:59:59"/>
             """
    end

    test "keyup event with parent live view as target" do
      code = """
      <TimeInput form="user" field="color" value="23:59:59" keyup="my_keyup" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="time" value="23:59:59"/>
             """
    end
  end
end
