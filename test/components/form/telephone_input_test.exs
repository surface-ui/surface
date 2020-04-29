defmodule Surface.Components.Form.TelephoneInputTest do
  use ExUnit.Case

  import ComponentTestHelper

  alias Surface.Components.Form.TelephoneInput, warn: false

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <TelephoneInput form="user" field="phone" />
      """

      assert render_live(code) =~ """
             <input id="user_phone" name="user[phone]" type="tel"/>
             """
    end

    test "setting the value" do
      code = """
      <TelephoneInput form="user" field="phone" value="phone_no" />
      """

      assert render_live(code) =~ """
             <input id="user_phone" name="user[phone]" type="tel" value="phone_no"/>
             """
    end

    test "passing other options" do
      code = """
      <TelephoneInput form="user" field="phone" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[phone]" type="tel"/>
             """
    end

    test "blur event with parent live view as target" do
      code = """
      <TelephoneInput form="user" field="color" value="phone_no" blur="my_blur" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-blur="my_blur" type="tel" value="phone_no"/>
             """
    end

    test "focus event with parent live view as target" do
      code = """
      <TelephoneInput form="user" field="color" value="phone_no" focus="my_focus" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-focus="my_focus" type="tel" value="phone_no"/>
             """
    end

    test "capture click event with parent live view as target" do
      code = """
      <TelephoneInput form="user" field="color" value="phone_no" capture_click="my_click" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-capture-click="my_click" type="tel" value="phone_no"/>
             """
    end

    test "keydown event with parent live view as target" do
      code = """
      <TelephoneInput form="user" field="color" value="phone_no" keydown="my_keydown" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="tel" value="phone_no"/>
             """
    end

    test "keyup event with parent live view as target" do
      code = """
      <TelephoneInput form="user" field="color" value="phone_no" keyup="my_keyup" />
      """

      assert render_live(code) =~ """
             <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="tel" value="phone_no"/>
             """
    end
  end
end
