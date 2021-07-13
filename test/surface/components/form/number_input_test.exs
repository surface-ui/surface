defmodule Surface.Components.Form.NumberInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.NumberInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <NumberInput form="user" field={:age} />
        """
      end

    assert html =~ """
           <input id="user_age" name="user[age]" type="number">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <NumberInput form="user" field="age" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <NumberInput form="user" field="age" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <NumberInput form="user" field="age" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_age" name="user[age]" type="number">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <NumberInput form="user" field="color" value="33" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <NumberInput form="user" field="age" id="old" name="old" />
        """
      end

    assert html =~ """
           <input id="old" name="old" type="number">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <NumberInput form="user" field="age" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_age" name="user[age]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="number">
           """
  end
end

defmodule Surface.Components.Form.NumberInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Input
  alias Surface.Components.Form.NumberInput

  test ":default_class config" do
    using_config NumberInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <NumberInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end

  test "component inherits :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      html =
        render_surface do
          ~F"""
          <NumberInput/>
          """
        end

      assert html =~ ~r/class="inherited_default_class"/
    end
  end

  test ":default_class config overrides inherited :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      using_config NumberInput, default_class: "default_class" do
        html =
          render_surface do
            ~F"""
            <NumberInput/>
            """
          end

        assert html =~ ~r/class="default_class"/
      end
    end
  end
end
