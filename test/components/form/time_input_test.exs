defmodule Surface.Components.Form.TimeInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TimeInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="time" />
        """
      end

    assert html =~ """
           <input id="user_time" name="user[time]" type="time">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field={{ :time }} />
        """
      end

    assert html =~ """
           <input id="user_time" name="user[time]" type="time">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="time" value="23:59:59" />
        """
      end

    assert html =~ """
           <input id="user_time" name="user[time]" type="time" value="23:59:59">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="time" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="time" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="time" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_time" name="user[time]" type="time">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="time" value="23:59:59">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="time" value="23:59:59">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="time" value="23:59:59">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="time" value="23:59:59">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="time" value="23:59:59">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="time" id="start_at" name="start_at" />
        """
      end

    assert html =~ """
           <input id="start_at" name="start_at" type="time">
           """
  end
end

defmodule Surface.Components.Form.TimeInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.TimeInput

  test ":default_class config" do
    using_config TimeInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <TimeInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
