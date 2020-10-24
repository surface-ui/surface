defmodule Surface.Components.Form.ColorInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form.ColorInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" type="color"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" type="color" value="mycolor"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" class="input"/>
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" class="input primary"/>
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[color]" type="color"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="color" value="mycolor"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="color" value="mycolor"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="color" value="mycolor"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="color" value="mycolor"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <ColorInput form="user" field="color" value="mycolor" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="color" value="mycolor"/>
           """
  end
end

defmodule Surface.Components.Form.ColorInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.ColorInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config ColorInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <ColorInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
