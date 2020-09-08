defmodule Surface.Components.Form.RangeInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  alias Surface.Components.Form.RangeInput, warn: false

  test "empty input" do
    code = """
    <RangeInput form="volume" field="percent"/>
    """

    assert render_live(code) =~ """
           <input id="volume_percent" name="volume[percent]" type="range"/>
           """
  end

  test "setting min, max and step" do
    code = """
    <RangeInput form="volume" field="percent" min="0" max="100" step="50"/>
    """

    assert render_live(code) =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" step="50" type="range"/>
           """
  end

  test "setting the value" do
    code = """
    <RangeInput form="volume" field="percent" min="0" max="100" value="25"/>
    """

    assert render_live(code) =~ """
           <input id="volume_percent" max="100" min="0" name="volume[percent]" type="range" value="25"/>
           """
  end

  test "setting the class" do
    code = """
    <RangeInput form="volume" field="percent" min="0" max="100" class="input" />
    """

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code = """
    <RangeInput form="volume" field="percent" min="0" max="100" class="input primary" />
    """

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code = """
    <RangeInput form="volume" field="percent" min="0" max="100" opts={{ id: "myid" }} />
    """

    assert render_live(code) =~ """
           <input id="myid" max="100" min="0" name="volume[percent]" type="range"/>
           """
  end

  test "blur event with parent live view as target" do
    code = """
    <RangeInput form="user" field="color" value="25" blur="my_blur" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="range" value="25"/>
           """
  end

  test "focus event with parent live view as target" do
    code = """
    <RangeInput form="user" field="color" value="25" focus="my_focus" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="range" value="25"/>
           """
  end

  test "capture click event with parent live view as target" do
    code = """
    <RangeInput form="user" field="color" value="25" capture_click="my_click" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="range" value="25"/>
           """
  end

  test "keydown event with parent live view as target" do
    code = """
    <RangeInput form="user" field="color" value="25" keydown="my_keydown" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="range" value="25"/>
           """
  end

  test "keyup event with parent live view as target" do
    code = """
    <RangeInput form="user" field="color" value="25" keyup="my_keyup" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="range" value="25"/>
           """
  end
end

defmodule Surface.Components.Form.RangeInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.RangeInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config RangeInput, default_class: "default_class" do
      code = """
      <RangeInput/>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
