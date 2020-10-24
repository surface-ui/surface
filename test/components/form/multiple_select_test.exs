defmodule Surface.Components.Form.MultipleSelectTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.MultipleSelect, warn: false

  import ComponentTestHelper

  test "emtpy multiple select" do
    code =
      quote do
        ~H"""
        <MultipleSelect form="user" field="roles" />
        """
      end

    assert render_live(code) =~ """
           <select id="user_roles" multiple="" name="user[roles][]"></select>
           """
  end

  test "setting the options" do
    code =
      quote do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} />
        """
      end

    assert render_live(code) =~ """
           <select id="user_roles" multiple="" name="user[roles][]">\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} class="select" />
        """
      end

    assert render_live(code) =~ ~r/class="select"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} class="select primary" />
        """
      end

    assert render_live(code) =~ ~r/class="select primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} opts={{ selected: ["admin"] }} />
        """
      end

    assert render_live(code) =~ """
           <select id="user_roles" multiple="" name="user[roles][]">\
           <option value="admin" selected="selected">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end
end

defmodule Surface.Components.Form.MultipleSelectConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.MultipleSelect, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config MultipleSelect, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <MultipleSelect />
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
