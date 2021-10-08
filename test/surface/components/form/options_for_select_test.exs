defmodule Surface.Components.Form.OptionsForSelectTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.OptionsForSelect

  test "empty options" do
    html =
      render_surface do
        ~F"""
        <OptionsForSelect />
        """
      end

    assert html == "\n"
  end

  test "setting the options" do
    html =
      render_surface do
        ~F"""
        <OptionsForSelect options={["Admin": "admin", "User": "user"]} />
        """
      end

    assert html =~ """
           <option value="admin">Admin</option>\
           <option value="user">User</option>
           """
  end

  test "passing selected value" do
    html =
      render_surface do
        ~F"""
        <OptionsForSelect options={["Admin": "admin", "User": "user"]} selected={"admin"} />
        """
      end

    assert html =~ """
           <option selected value="admin">Admin</option>\
           <option value="user">User</option>
           """
  end

  test "passing multiple selected values" do
    html =
      render_surface do
        ~F"""
        <OptionsForSelect options={["Admin": "admin", "User": "user"]} selected={["admin", "user"]} />
        """
      end

    assert html =~ """
           <option selected value="admin">Admin</option>\
           <option selected value="user">User</option>
           """
  end
end
