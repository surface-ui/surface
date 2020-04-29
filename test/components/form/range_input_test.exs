defmodule Surface.Components.Form.RangeInputTest do
  use ExUnit.Case

  import ComponentTestHelper

  alias Surface.Components.Form.RangeInput, warn: false

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <RangeInput form="volume" field="percent" min="0" max="100"/>
      """

      assert render_live(code) =~ """
             <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range"/>
             """
    end

    test "setting the value" do
      code = """
      <RangeInput form="volume" field="percent" min="0" max="100" value="25"/>
      """

      assert render_live(code) =~ """
             <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range" value="25"/>
             """
    end

    test "passing other options" do
      code = """
      <RangeInput form="volume" field="percent" min="0" max="100" opts={{ id: "myid" }} />
      """

      assert render_live(code) =~ """
             <input id="myid" max="100" min="0" name="volume[percent]" type="range"/>
             """
    end

    test "blur event with parent live view as target" do
      code = """
      <RangeInput form="user" field="color" value="25" blur="my_blur" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-blur="my_blur" type="range" value="25"/>
             """
    end

    test "focus event with parent live view as target" do
      code = """
      <RangeInput form="user" field="color" value="25" focus="my_focus" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-focus="my_focus" type="range" value="25"/>
             """
    end

    test "capture click event with parent live view as target" do
      code = """
      <RangeInput form="user" field="color" value="25" capture_click="my_click" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-capture-click="my_click" type="range" value="25"/>
             """
    end

    test "keydown event with parent live view as target" do
      code = """
      <RangeInput form="user" field="color" value="25" keydown="my_keydown" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="range" value="25"/>
             """
    end

    test "keyup event with parent live view as target" do
      code = """
      <RangeInput form="user" field="color" value="25" keyup="my_keyup" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="range" value="25"/>
             """
    end
  end
end
