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

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59"
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
