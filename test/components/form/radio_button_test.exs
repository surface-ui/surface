defmodule Surface.Components.Form.RadioButtonTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.RadioButton, warn: false

  import ComponentTestHelper

  test "radio" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin"/>
        """
      end

    assert render_live(code) =~ """
           <input id="user_role_admin" name="user[role]" type="radio" value="admin"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" class="radio" />
        """
      end

    assert render_live(code) =~ ~r/class="radio"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" class="radio primary" />
        """
      end

    assert render_live(code) =~ ~r/class="radio primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" name="user[role]" type="radio" value="admin"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_role_admin" name="user[role]" phx-blur="my_blur" type="radio" value="admin"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_role_admin" name="user[role]" phx-focus="my_focus" type="radio" value="admin"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_role_admin" name="user[role]" phx-capture-click="my_click" type="radio" value="admin"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_role_admin" name="user[role]" phx-keydown="my_keydown" type="radio" value="admin"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" value="admin" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_role_admin" name="user[role]" phx-keyup="my_keyup" type="radio" value="admin"/>
           """
  end

  test "setting id and name through props" do
    code =
      quote do
        ~H"""
        <RadioButton form="user" field="role" id="role" name="role" />
        """
      end

    assert render_live(code) =~ """
           <input id="role" name="role" type="radio" value="" checked="checked"/>
           """
  end
end

defmodule Surface.Components.Form.RadioButtonConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.RadioButton, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config RadioButton, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <RadioButton/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
