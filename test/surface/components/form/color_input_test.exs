defmodule Surface.Components.Form.ColorInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.ColorInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" type="color">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field={:color} />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" type="color">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" value="mycolor" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" type="color" value="mycolor">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" class="input"/>
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" class="input primary"/>
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_color" name="user[color]" type="color">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" value="mycolor" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" id="color" name="color" />
        """
      end

    assert html =~ """
           <input id="color" name="color" type="color">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <ColorInput form="user" field="color" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="color">
           """
  end
end

defmodule Surface.Components.Form.ColorInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.ColorInput

  test ":default_class config" do
    using_config ColorInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <ColorInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
