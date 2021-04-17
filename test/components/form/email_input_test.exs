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

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <EmailInput form="user" field="color" value="admin@gmail.com"
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
