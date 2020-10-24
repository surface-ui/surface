defmodule Surface.Components.Form.TelephoneInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  alias Surface.Components.Form.TelephoneInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="phone" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_phone" name="user[phone]" type="tel"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="phone" value="phone_no" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_phone" name="user[phone]" type="tel" value="phone_no"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="phone" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="phone" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="phone" opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[phone]" type="tel"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="tel" value="phone_no"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="tel" value="phone_no"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="tel" value="phone_no"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="tel" value="phone_no"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="tel" value="phone_no"/>
           """
  end
end

defmodule Surface.Components.Form.TelephoneInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.TelephoneInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config TelephoneInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <TelephoneInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
