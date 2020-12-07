defmodule Surface.Components.Form.TextInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TextInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="name" />
        """
      end

    assert html =~ """
           <input id="user_name" name="user[name]" type="text">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="name" value="Max" />
        """
      end

    assert html =~ """
           <input id="user_name" name="user[name]" type="text" value="Max">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="name" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="name" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="name" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_name" name="user[name]" type="text">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="color" value="Max" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="text" value="Max">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="color" value="Max" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="text" value="Max">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="color" value="Max" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="text" value="Max">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="color" value="Max" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="text" value="Max">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="color" value="Max" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="text" value="Max">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <TextInput form="user" field="name" id="username" name="username" />
        """
      end

    assert html =~ """
           <input id="username" name="username" type="text">
           """
  end
end

defmodule Surface.Components.Form.TextInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.TextInput

  test ":default_class config" do
    using_config TextInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <TextInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
