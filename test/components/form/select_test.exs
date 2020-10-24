defmodule Surface.Components.Form.SelectTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.Select, warn: false

  import ComponentTestHelper

  test "empty select" do
    code =
      quote do
        ~H"""
        <Select form="user" field="role" />
        """
      end

    assert render_live(code) =~ """
           <select id="user_role" name="user[role]"></select>
           """
  end

  test "setting the options" do
    code =
      quote do
        ~H"""
        <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} />
        """
      end

    assert render_live(code) =~ """
           <select id="user_role" name="user[role]">\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} class="select" />
        """
      end

    assert render_live(code) =~ ~r/class="select"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} class="select primary" />
        """
      end

    assert render_live(code) =~ ~r/class="select primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <Select form="user" field="role" options={{ ["Admin": "admin", "User": "user"] }} opts={{ prompt: "Pick a role" }} />
        """
      end

    assert render_live(code) =~ """
           <select id="user_role" name="user[role]">\
           <option value="">Pick a role</option>\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end
end

defmodule Surface.Components.Form.SelectConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.Select, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config Select, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <Select />
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
