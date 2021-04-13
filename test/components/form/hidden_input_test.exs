defmodule Surface.Components.Form.HiddenInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.HiddenInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" />
        """
      end

    assert html =~ """
           <input id="user_token" name="user[token]" type="hidden">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field={{ :token }} />
        """
      end

    assert html =~ """
           <input id="user_token" name="user[token]" type="hidden">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" value="token" />
        """
      end

    assert html =~ """
           <input id="user_token" name="user[token]" type="hidden" value="token">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="token" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_token" name="user[token]" type="hidden">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="color" value="token" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="hidden" value="token">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="color" value="token" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="hidden" value="token">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="color" value="token" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="hidden" value="token">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="color" value="token" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="hidden" value="token">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="color" value="token" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="hidden" value="token">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <HiddenInput form="user" field="pass" id="token" name="token" />
        """
      end

    assert html =~ """
           <input id="token" name="token" type="hidden">
           """
  end
end
