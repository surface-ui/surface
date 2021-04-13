defmodule Surface.Components.Form.TelephoneInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TelephoneInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="phone" />
        """
      end

    assert html =~ """
           <input id="user_phone" name="user[phone]" type="tel">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field={{ :phone }} />
        """
      end

    assert html =~ """
           <input id="user_phone" name="user[phone]" type="tel">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="phone" value="phone_no" />
        """
      end

    assert html =~ """
           <input id="user_phone" name="user[phone]" type="tel" value="phone_no">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="phone" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="phone" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="phone" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_phone" name="user[phone]" type="tel">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="tel" value="phone_no">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="tel" value="phone_no">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="tel" value="phone_no">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="tel" value="phone_no">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="color" value="phone_no" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="tel" value="phone_no">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <TelephoneInput form="user" field="phone" id="telephone" name="telephone" />
        """
      end

    assert html =~ """
           <input id="telephone" name="telephone" type="tel">
           """
  end
end

defmodule Surface.Components.Form.TelephoneInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.TelephoneInput

  test ":default_class config" do
    using_config TelephoneInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <TelephoneInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
