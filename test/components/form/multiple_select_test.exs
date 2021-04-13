defmodule Surface.Components.Form.MultipleSelectTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.MultipleSelect

  test "emtpy multiple select" do
    html =
      render_surface do
        ~H"""
        <MultipleSelect form="user" field="roles" />
        """
      end

    assert html =~ """
           <select id="user_roles" multiple="" name="user[roles][]"></select>
           """
  end

  test "setting the options" do
    html =
      render_surface do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} />
        """
      end

    assert html =~ """
           <select id="user_roles" multiple="" name="user[roles][]">\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} class="select" />
        """
      end

    assert html =~ ~r/class="select"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} class="select primary" />
        """
      end

    assert html =~ ~r/class="select primary"/
  end

  test "passing selected" do
    html =
      render_surface do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} selected="admin"/>
        """
      end

    assert html =~ """
           <select id="user_roles" multiple="" name="user[roles][]">\
           <option value="admin" selected>Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} opts={{ disabled: "disabled" }}/>
        """
      end

    assert html =~ """
           <select disabled="disabled" id="user_roles" multiple="" name="user[roles][]">\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <MultipleSelect form="user" field="roles" options={{ ["Admin": "admin", "User": "user"] }} id="roles" name="roles[]"/>
        """
      end

    assert html =~ """
           <select id="roles" multiple="" name="roles[]">\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end
end

defmodule Surface.Components.Form.MultipleSelectConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.MultipleSelect

  test ":default_class config" do
    using_config MultipleSelect, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <MultipleSelect />
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
