defmodule Surface.Components.Form.SelectTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.Select

  test "empty select" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" />
        """
      end

    assert html =~ """
           <select id="user_role" name="user[role]"></select>
           """
  end

  test "select with atom field" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field={:role} />
        """
      end

    assert html =~ """
           <select id="user_role" name="user[role]"></select>
           """
  end

  test "setting the options" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" options={["Admin": "admin", "User": "user"]} />
        """
      end

    assert html =~ """
           <select id="user_role" name="user[role]">\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" options={["Admin": "admin", "User": "user"]} class="select" />
        """
      end

    assert html =~ ~r/class="select"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" options={["Admin": "admin", "User": "user"]} class="select primary" />
        """
      end

    assert html =~ ~r/class="select primary"/
  end

  test "setting the prompt" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" options={["Admin": "admin", "User": "user"]} prompt="Pick a role"/>
        """
      end

    assert html =~ """
           <select id="user_role" name="user[role]">\
           <option value="">Pick a role</option>\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "setting the default selected element" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" options={["Admin": "admin", "User": "user"]} selected="user"/>
        """
      end

    assert html =~ """
           <select id="user_role" name="user[role]">\
           <option value="admin">Admin</option>\
           <option value="user" selected>User</option>\
           </select>
           """
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" options={["Admin": "admin", "User": "user"]} opts={disabled: true}/>
        """
      end

    assert html =~ """
           <select id="user_role" name="user[role]" disabled>\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <Select form="user" field="role" id="role" name="role" options={["Admin": "admin", "User": "user"]}/>
        """
      end

    assert html =~ """
           <select id="role" name="role">\
           <option value="admin">Admin</option>\
           <option value="user">User</option>\
           </select>
           """
  end
end

defmodule Surface.Components.Form.SelectConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Select

  test ":default_class config" do
    using_config Select, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <Select />
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
