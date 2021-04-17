defmodule Surface.Components.Form.ColorInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.ColorInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" type="color">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field={{ :color }} />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" type="color">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" type="color" value="mycolor">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" class="input"/>
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" class="input primary"/>
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_color" name="user[color]" type="color">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor"
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
        <ColorInput form="user" field="color" id="color" name="color" />
        """
      end

    assert html =~ """
           <input id="color" name="color" type="color">
           """
  end
end

defmodule Surface.Components.Form.ColorInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.ColorInput

  test ":default_class config" do
    using_config ColorInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <ColorInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
