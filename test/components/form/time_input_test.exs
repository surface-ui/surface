defmodule Surface.Components.Form.TimeInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  alias Surface.Components.Form.TimeInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="time" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_time" name="user[time]" type="time"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="time" value="23:59:59" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_time" name="user[time]" type="time" value="23:59:59"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="time" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="time" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="time" opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[time]" type="time"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="time" value="23:59:59"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="time" value="23:59:59"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="time" value="23:59:59"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="time" value="23:59:59"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TimeInput form="user" field="color" value="23:59:59" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="time" value="23:59:59"/>
           """
  end
end

defmodule Surface.Components.Form.TimeInputConfigTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.TimeInput, warn: false

  test ":default_class config" do
    using_config TimeInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <TimeInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
