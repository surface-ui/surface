defmodule Surface.Components.Form.TelephoneInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.TelephoneInput, warn: false

  import ComponentTestHelper

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
      <TelephoneInput form="user" field="phone" value="myphone" />
      """

      assert render_live(code) =~ """
             <input id="user_phone" name="user[phone]" type="tel" value="myphone"/>
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
  end
end
