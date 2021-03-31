defmodule Surface.Components.Form.NumberInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.NumberInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="age" />
        """
      end

    assert html =~ """
           <input id="user_age" name="user[age]" type="number">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field={{ :age }} />
        """
      end

    assert html =~ """
           <input id="user_age" name="user[age]" type="number">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="age" value="33" />
        """
      end

    assert html =~ """
           <input id="user_age" name="user[age]" type="number" value="33">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="age" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="age" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="age" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_age" name="user[age]" type="number">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="color" value="33" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="number" value="33">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="color" value="33" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="number" value="33">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="color" value="33" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="number" value="33">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="color" value="33" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="number" value="33">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="color" value="33" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="number" value="33">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <NumberInput form="user" field="age" id="old" name="old" />
        """
      end

    assert html =~ """
           <input id="old" name="old" type="number">
           """
  end
end

defmodule Surface.Components.Form.NumberInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.NumberInput

  test ":default_class config" do
    using_config NumberInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <NumberInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
