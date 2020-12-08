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

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Reset value="ResetTheForm" blur="my_blur" />
        """
      end

    assert html =~ """
           <input phx-blur="my_blur" type="reset" value="ResetTheForm">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Reset value="ResetTheForm" focus="my_focus" />
        """
      end

    assert html =~ """
           <input phx-focus="my_focus" type="reset" value="ResetTheForm">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Reset value="ResetTheForm" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input phx-capture-click="my_click" type="reset" value="ResetTheForm">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Reset value="ResetTheForm" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input phx-keydown="my_keydown" type="reset" value="ResetTheForm">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Reset value="ResetTheForm" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input phx-keyup="my_keyup" type="reset" value="ResetTheForm">
           """
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
