defmodule Surface.Components.Form.ResetTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.Reset

  test "empty reset" do
    html =
      render_surface do
        ~H"""
        <Reset />
        """
      end

    assert html =~ """
           <input type="reset" value="Reset">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <Reset value="ResetTheForm" />
        """
      end

    assert html =~ """
           <input type="reset" value="ResetTheForm">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <Reset class="button" />
        """
      end

    assert html =~ ~r/class="button"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <Reset class="button primary" />
        """
      end

    assert html =~ ~r/class="button primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <Reset opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" type="reset" value="Reset">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Reset value="ResetTheForm"
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
        <Reset id="countdown" name="countdown" />
        """
      end

    assert html =~ """
           <input id="countdown" name="countdown" type="reset" value="Reset">
           """
  end
end
