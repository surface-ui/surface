defmodule Surface.Components.Form.PasswordInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.PasswordInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="password" />
        """
      end

    assert html =~ """
           <input id="user_password" name="user[password]" type="password">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field={{ :password }} />
        """
      end

    assert html =~ """
           <input id="user_password" name="user[password]" type="password">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="password" value="secret" />
        """
      end

    assert html =~ """
           <input id="user_password" name="user[password]" type="password" value="secret">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="password" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="password" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="password" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_password" name="user[password]" type="password">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="password" value="secret">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="password" value="secret">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="password" value="secret">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="password" value="secret">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="password" value="secret">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <PasswordInput form="user" field="password" id="secret" name="secret" />
        """
      end

    assert html =~ """
           <input id="secret" name="secret" type="password">
           """
  end
end

defmodule Surface.Components.Form.PasswordInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.PasswordInput

  test ":default_class config" do
    using_config PasswordInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <PasswordInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
