defmodule Surface.Components.Form.RangeInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  alias Surface.Components.Form.RangeInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <RangeInput form="volume" field="percent"/>
        """
      end

    assert render_live(code) =~ """
           <input id="volume_percent" name="volume[percent]" type="range"/>
           """
  end

  test "setting min, max and step" do
    code =
      quote do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" step="50"/>
        """
      end

    assert render_live(code) =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" step="50" type="range"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" value="25"/>
        """
      end

    assert render_live(code) =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range" value="25"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <RangeInput form="volume" field="percent" min="0" max="100" opts={{ disabled: "disabled" }} />
        """
      end

    assert render_live(code) =~ """
           <input disabled="disabled" id="volume_percent" max="100" min="0" name="volume[percent]" type="range"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RangeInput form="user" field="color" value="25" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="range" value="25"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RangeInput form="user" field="color" value="25" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="range" value="25"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RangeInput form="user" field="color" value="25" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="range" value="25"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RangeInput form="user" field="color" value="25" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="range" value="25"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RangeInput form="user" field="color" value="25" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="range" value="25"/>
           """
  end

  test "setting id and name through props" do
    code =
      quote do
        ~H"""
        <RangeInput form="user" field="percent" id="rate" name="rate" />
        """
      end

    assert render_live(code) =~ """
           <input id="rate" name="rate" type="range"/>
           """
  end
end

defmodule Surface.Components.Form.RangeInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.RangeInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config RangeInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <RangeInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
