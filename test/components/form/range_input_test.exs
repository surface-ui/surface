defmodule Surface.Components.Form.RangeInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.RangeInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="volume" field="percent" />
        """
      end

    assert html =~ """
           <input id="volume_percent" name="volume[percent]" type="range">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="volume" field={{ :percent }} />
        """
      end

    assert html =~ """
           <input id="volume_percent" name="volume[percent]" type="range">
           """
  end

  test "setting min, max and step" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" step="50" />
        """
      end

    assert html =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" step="50" type="range">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" value="25" />
        """
      end

    assert html =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range" value="25">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" opts={{ disabled: "disabled" }} />
        """
      end

    assert html =~ """
           <input disabled="disabled" id="volume_percent" max="100" min="0" name="volume[percent]" type="range">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="user" field="color" value="25" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="range" value="25">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="user" field="color" value="25" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="range" value="25">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="user" field="color" value="25" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="range" value="25">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="user" field="color" value="25" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="range" value="25">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="user" field="color" value="25" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="range" value="25">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="user" field="percent" id="rate" name="rate" />
        """
      end

    assert html =~ """
           <input id="rate" name="rate" type="range">
           """
  end
end

defmodule Surface.Components.Form.RangeInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.RangeInput

  test ":default_class config" do
    using_config RangeInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <RangeInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
