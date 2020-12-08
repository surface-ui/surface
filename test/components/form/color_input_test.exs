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

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="color" value="mycolor">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="color" value="mycolor">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="color" value="mycolor">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="color" value="mycolor">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="color" value="mycolor">
           """
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
