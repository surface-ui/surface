defmodule Surface.Components.Form.ResetTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.Reset, warn: false

  import ComponentTestHelper

  test "empty reset" do
    code =
      quote do
        ~H"""
        <Reset />
        """
      end

    assert render_live(code) =~ """
           <input type="reset" value="Reset"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <Reset value="ResetTheForm" />
        """
      end

    assert render_live(code) =~ """
           <input type="reset" value="ResetTheForm"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <Reset class="button" />
        """
      end

    assert render_live(code) =~ ~r/class="button"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <Reset class="button primary" />
        """
      end

    assert render_live(code) =~ ~r/class="button primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <Reset opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" type="reset" value="Reset"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Reset value="ResetTheForm" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input phx-blur="my_blur" type="reset" value="ResetTheForm"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Reset value="ResetTheForm" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input phx-focus="my_focus" type="reset" value="ResetTheForm"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Reset value="ResetTheForm" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input phx-capture-click="my_click" type="reset" value="ResetTheForm"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Reset value="ResetTheForm" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input phx-keydown="my_keydown" type="reset" value="ResetTheForm"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Reset value="ResetTheForm" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input phx-keyup="my_keyup" type="reset" value="ResetTheForm"/>
           """
  end
end
