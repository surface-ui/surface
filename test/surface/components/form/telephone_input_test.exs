defmodule Surface.Components.Form.TelephoneInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TelephoneInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <TelephoneInput form="user" field={:phone} />
        """
      end

    assert html =~ """
           <input id="user_phone" name="user[phone]" type="tel">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <TelephoneInput form="user" field="phone" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <TelephoneInput form="user" field="phone" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <TelephoneInput form="user" field="phone" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_phone" name="user[phone]" type="tel">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <TelephoneInput form="user" field="color" value="phone_no" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <TelephoneInput form="user" field="phone" id="telephone" name="telephone" />
        """
      end

    assert html =~ """
           <input id="telephone" name="telephone" type="tel">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <TelephoneInput form="user" field="phone" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_phone" name="user[phone]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="tel">
           """
  end
end

defmodule Surface.Components.Form.TelephoneInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Input
  alias Surface.Components.Form.TelephoneInput

  test ":default_class config" do
    using_config TelephoneInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <TelephoneInput/>
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
          <TelephoneInput/>
          """
        end

      assert html =~ ~r/class="inherited_default_class"/
    end
  end

  test ":default_class config overrides inherited :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      using_config TelephoneInput, default_class: "default_class" do
        html =
          render_surface do
            ~F"""
            <TelephoneInput/>
            """
          end

        assert html =~ ~r/class="default_class"/
      end
    end
  end
end
