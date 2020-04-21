defmodule Surface.Components.Form.HiddenInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.HiddenInput, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <HiddenInput form="user" field="token" />
      """

      assert render_live(code) =~ """
             <input id="user_token" name="user[token]" type="hidden"/>
             """
    end

    test "setting the value" do
      code = """
      <HiddenInput form="user" field="token" value="mytoken" />
      """

      assert render_live(code) =~ """
             <input id="user_token" name="user[token]" type="hidden" value="mytoken"/>
             """
    end

    test "passing other options" do
      code = """
      <HiddenInput form="user" field="token" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="user[token]" type="hidden"/>
             """
    end
  end
end
