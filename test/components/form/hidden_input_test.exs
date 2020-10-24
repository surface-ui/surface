defmodule Surface.Components.Form.HiddenInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form.HiddenInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="token" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_token" name="user[token]" type="hidden"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="token" value="token" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_token" name="user[token]" type="hidden" value="token"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="token" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="token" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="token" opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[token]" type="hidden"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="color" value="token" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="hidden" value="token"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="color" value="token" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="hidden" value="token"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="color" value="token" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="hidden" value="token"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="color" value="token" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="hidden" value="token"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <HiddenInput form="user" field="color" value="token" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="hidden" value="token"/>
           """
  end
end
