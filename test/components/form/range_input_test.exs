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

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <RangeInput form="user" field="color" value="25"
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
