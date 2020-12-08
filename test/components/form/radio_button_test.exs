defmodule Surface.Components.Form.RadioButtonTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.RadioButton

  test "radio" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin"/>
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" type="radio" value="admin">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" class="radio" />
        """
      end

    assert html =~ ~r/class="radio"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" class="radio primary" />
        """
      end

    assert html =~ ~r/class="radio primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_role_admin" name="user[role]" type="radio" value="admin">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" phx-blur="my_blur" type="radio" value="admin">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" phx-focus="my_focus" type="radio" value="admin">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" phx-capture-click="my_click" type="radio" value="admin">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" phx-keydown="my_keydown" type="radio" value="admin">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" phx-keyup="my_keyup" type="radio" value="admin">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" id="role" name="role" />
        """
      end

    assert html =~ """
           <input id="role" name="role" type="radio" value="" checked>
           """
  end
end

defmodule Surface.Components.Form.RadioButtonConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.RadioButton

  test ":default_class config" do
    using_config RadioButton, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <RadioButton/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
