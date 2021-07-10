defmodule Surface.Components.Form.TimeInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TimeInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <TimeInput form="user" field={:time} />
        """
      end

    assert html =~ """
           <input id="user_time" name="user[time]" type="time">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <TimeInput form="user" field="time" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <TimeInput form="user" field="time" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <TimeInput form="user" field="time" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_time" name="user[time]" type="time">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <TimeInput form="user" field="color" value="23:59:59" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <TimeInput form="user" field="time" id="start_at" name="start_at" />
        """
      end

    assert html =~ """
           <input id="start_at" name="start_at" type="time">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <TimeInput form="user" field="time" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_time" name="user[time]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="time">
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
          ~F"""
          <TimeInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
