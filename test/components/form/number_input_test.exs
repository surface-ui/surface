defmodule Surface.Components.Form.NumberInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form.NumberInput, warn: false

  test "empty input" do
    code = """
    <NumberInput form="user" field="age" />
    """

    assert render_live(code) =~ """
           <input id="user_age" name="user[age]" type="number"/>
           """
  end

  test "setting the value" do
    code = """
    <NumberInput form="user" field="age" value="33" />
    """

    assert render_live(code) =~ """
           <input id="user_age" name="user[age]" type="number" value="33"/>
           """
  end

  test "setting the class" do
    code = """
    <NumberInput form="user" field="age" class="input" />
    """

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code = """
    <NumberInput form="user" field="age" class="input primary" />
    """

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code = """
    <NumberInput form="user" field="age" opts={{ id: "myid", autofocus: "autofocus" }} />
    """

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[age]" type="number"/>
           """
  end

  test "blur event with parent live view as target" do
    code = """
    <NumberInput form="user" field="color" value="33" blur="my_blur" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="number" value="33"/>
           """
  end

  test "focus event with parent live view as target" do
    code = """
    <NumberInput form="user" field="color" value="33" focus="my_focus" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="number" value="33"/>
           """
  end

  test "capture click event with parent live view as target" do
    code = """
    <NumberInput form="user" field="color" value="33" capture_click="my_click" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="number" value="33"/>
           """
  end

  test "keydown event with parent live view as target" do
    code = """
    <NumberInput form="user" field="color" value="33" keydown="my_keydown" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="number" value="33"/>
           """
  end

  test "keyup event with parent live view as target" do
    code = """
    <NumberInput form="user" field="color" value="33" keyup="my_keyup" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="number" value="33"/>
           """
  end
end

defmodule Surface.Components.Form.NumberInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.NumberInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config NumberInput, default_class: "default_class" do
      code = """
      <NumberInput/>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
