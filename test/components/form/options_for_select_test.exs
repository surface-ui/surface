defmodule Surface.Components.Form.OptionsForSelectTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.OptionsForSelect, warn: false

  import ComponentTestHelper

  test "empty options" do
    code = """
    <OptionsForSelect />
    """

    assert render_live(code) == "\n"
  end

  test "setting the options" do
    code = """
    <OptionsForSelect options={{ ["Admin": "admin", "User": "user"] }} />
    """

    assert render_live(code) =~ """
           <option value="admin">Admin</option>\
           <option value="user">User</option>
           """
  end

  test "passing selected value" do
    code = """
    <OptionsForSelect options={{ ["Admin": "admin", "User": "user"] }} selected={{ "admin" }} />
    """

    assert render_live(code) =~ """
           <option value="admin" selected="selected">Admin</option>\
           <option value="user">User</option>
           """
  end

  test "passing multiple selected values" do
    code = """
    <OptionsForSelect options={{ ["Admin": "admin", "User": "user"] }} selected={{ ["admin", "user"] }} />
    """

    assert render_live(code) =~ """
           <option value="admin" selected="selected">Admin</option>\
           <option value="user" selected="selected">User</option>
           """
  end
end
