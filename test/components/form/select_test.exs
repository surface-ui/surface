defmodule Surface.Components.Form.SelectTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.Select, warn: false

  import ComponentTestHelper

  test "select" do
    code = """
    <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} />
    """

    assert render_live(code) =~ """
           <select id="user_role" name="user[role]"><option value="admin">Admin</option><option value="user">User</option></select>
           """
  end

  test "setting the class" do
    code = """
    <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} class="select" />
    """

    assert render_live(code) =~ ~r/class="select"/
  end

  test "setting multiple classes" do
    code = """
    <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} class="select primary" />
    """

    assert render_live(code) =~ ~r/class="select primary"/
  end

  test "passing other options" do
    code = """
    <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} opts={{ prompt: "Pick a role" }} />
    """

    assert render_live(code) =~ """
           <select id="user_role" name="user[role]"><option value="">Pick a role</option><option value="admin">Admin</option><option value="user">User</option></select>
           """
  end
end

defmodule Surface.Components.Form.SelectConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.Select, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config Select, default_class: "default_class" do
      code = """
      <Select />
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
