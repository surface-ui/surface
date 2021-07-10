defmodule Surface.Components.Form.RadioButtonTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.RadioButton

  test "radio" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field="role" value="admin"/>
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" type="radio" value="admin">
           """
  end

  test "radio with atom field" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field={:role} value="admin"/>
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" type="radio" value="admin">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field="role" value="admin" class="radio" />
        """
      end

    assert html =~ ~r/class="radio"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field="role" value="admin" class="radio primary" />
        """
      end

    assert html =~ ~r/class="radio primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field="role" value="admin" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_role_admin" name="user[role]" type="radio" value="admin">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field="role" value="admin" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field="role" id="role" name="role" />
        """
      end

    assert html =~ """
           <input id="role" name="role" type="radio" value="" checked>
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <RadioButton form="user" field="role" value="admin" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_role_admin" name="user[role]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="radio" value="admin">
           """
  end
end

defmodule Surface.Components.Form.RadioButtonConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.RadioButton

  test ":default_class config" do
    using_config RadioButton, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <RadioButton/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
