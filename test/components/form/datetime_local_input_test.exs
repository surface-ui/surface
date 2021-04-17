defmodule Surface.Components.Form.DateTimeLocalInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.DateTimeLocalInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <DateTimeLocalInput form="order" field="completed_at" />
        """
      end

    assert html =~ """
           <input id="order_completed_at" name="order[completed_at]" type="datetime-local">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30" />
        """
      end

    assert html =~ """
           <input id="order_completed_at" name="order[completed_at]" type="datetime-local" value="2020-05-05T19:30">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <DateTimeLocalInput form="order" field="completed_at" class="input"/>
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <DateTimeLocalInput form="order" field="completed_at" class="input primary"/>
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <DateTimeLocalInput form="order" field="completed_at" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="order_completed_at" name="order[completed_at]" type="datetime-local">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <DateTimeLocalInput form="order" field="completed_at" value="2020-05-05T19:30"
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
        <DateTimeLocalInput form="user" field="birth" id="birthday" name="birthday" />
        """
      end

    assert html =~ """
           <input id="birthday" name="birthday" type="datetime-local">
           """
  end
end

defmodule Surface.Components.Form.DateTimeLocalInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.DateTimeLocalInput

  test ":default_class config" do
    using_config DateTimeLocalInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <DateTimeLocalInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
