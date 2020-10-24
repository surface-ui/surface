defmodule Surface.Components.Form.DateInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  alias Surface.Components.Form.DateInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="birthday" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_birthday" name="user[birthday]" type="date"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="birthday" value="mybirthday" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_birthday" name="user[birthday]" type="date" value="mybirthday"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="birthday" class="input"/>
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="birthday" class="input primary"/>
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="birthday" opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[birthday]" type="date"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="date" value="mybirthday"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="date" value="mybirthday"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="date" value="mybirthday"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="date" value="mybirthday"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <DateInput form="user" field="color" value="mybirthday" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="date" value="mybirthday"/>
           """
  end
end

defmodule Surface.Components.Form.DateInputConfigTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.DateInput, warn: false

  test ":default_class config" do
    using_config DateInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <DateInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
