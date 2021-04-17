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

  test "radio with atom field" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field={{ :role }} value="admin"/>
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

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RadioButton form="user" field="role" value="admin"
          capture_click="my_capture_click"
          click="my_click"
          window_focus="my_window_focus"
          window_blur="my_window_blur"
          focus="my_focus"
          blur="my_blur"
          window_keyup="my_window_keyup"
          window_keydown="my_window_keydown"
          keyup="my_keyup"
          keydown="my_keydown"
        />
        """
      end

    assert html =~ ~s(phx-capture-click="my_capture_click")
    assert html =~ ~s(phx-click="my_click")
    assert html =~ ~s(phx-window-focus="my_window_focus")
    assert html =~ ~s(phx-window-blur="my_window_blur")
    assert html =~ ~s(phx-focus="my_focus")
    assert html =~ ~s(phx-blur="my_blur")
    assert html =~ ~s(phx-window-keyup="my_window_keyup")
    assert html =~ ~s(phx-window-keydown="my_window_keydown")
    assert html =~ ~s(phx-keyup="my_keyup")
    assert html =~ ~s(phx-keydown="my_keydown")
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
