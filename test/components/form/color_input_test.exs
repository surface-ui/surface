defmodule Surface.Components.Form.ColorInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.ColorInput, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <ColorInput form="user" field="color" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" type="color"/>
             """
    end

    test "setting the value" do
      code = """
      <ColorInput form="user" field="color" value="mycolor" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" type="color" value="mycolor"/>
             """
    end

    test "passing other options" do
      code = """
      <ColorInput form="user" field="color" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[color]" type="color"/>
             """
    end
  end
end
