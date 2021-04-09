defmodule Surface.Components.Form.EmailInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.EmailInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="email" />
        """
      end

    assert html =~ """
           <input id="user_email" name="user[email]" type="email">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field={{ :email }} />
        """
      end

    assert html =~ """
           <input id="user_email" name="user[email]" type="email">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="email" value="admin@gmail.com" />
        """
      end

    assert html =~ """
           <input id="user_email" name="user[email]" type="email" value="admin@gmail.com">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="email" value="admin@gmail.com" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="email" value="admin@gmail.com" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="email" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_email" name="user[email]" type="email">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="color" value="admin@gmail.com" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="email" value="admin@gmail.com">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="color" value="admin@gmail.com" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="email" value="admin@gmail.com">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="color" value="admin@gmail.com" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="email" value="admin@gmail.com">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="color" value="admin@gmail.com" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="email" value="admin@gmail.com">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="color" value="admin@gmail.com" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="email" value="admin@gmail.com">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="email" id="myemail" name="myemail" />
        """
      end

    assert html =~ """
           <input id="myemail" name="myemail" type="email">
           """
  end
end

defmodule Surface.Components.Form.EmailInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.EmailInput

  test ":default_class config" do
    using_config EmailInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <EmailInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
