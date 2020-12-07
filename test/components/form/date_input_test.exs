defmodule Surface.Components.Form.DateInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.DateInput, warn: false

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="birthday" />
        """
      end

    assert html =~ """
           <input id="user_birthday" name="user[birthday]" type="date">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="birthday" value="mybirthday" />
        """
      end

    assert html =~ """
           <input id="user_birthday" name="user[birthday]" type="date" value="mybirthday">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="birthday" class="input"/>
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="birthday" class="input primary"/>
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="birthday" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_birthday" name="user[birthday]" type="date">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="date" value="mybirthday">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="date" value="mybirthday">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="date" value="mybirthday">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="date" value="mybirthday">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="date" value="mybirthday">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <DateInput form="user" field="birth" id="birthday" name="birthday" />
        """
      end

    assert html =~ """
           <input id="birthday" name="birthday" type="date">
           """
  end
end

defmodule Surface.Components.Form.DateInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.DateInput

  test ":default_class config" do
    using_config DateInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <DateInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
