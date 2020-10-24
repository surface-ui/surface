defmodule Surface.Components.Form.PasswordInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form.PasswordInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="password" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_password" name="user[password]" type="password"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="password" value="secret" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_password" name="user[password]" type="password" value="secret"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="password" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="password" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="password" opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[password]" type="password"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="password" value="secret"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="password" value="secret"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="password" value="secret"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="password" value="secret"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <PasswordInput form="user" field="color" value="secret" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="password" value="secret"/>
           """
  end
end

defmodule Surface.Components.Form.PasswordInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.PasswordInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config PasswordInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <PasswordInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
