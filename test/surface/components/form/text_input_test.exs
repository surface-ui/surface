defmodule Surface.Components.Form.TextInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TextInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" />
        """
      end

    assert html =~ """
           <input id="user_name" name="user[name]" type="text">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field={:name} />
        """
      end

    assert html =~ """
           <input id="user_name" name="user[name]" type="text">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" value="Max" />
        """
      end

    assert html =~ """
           <input id="user_name" name="user[name]" type="text" value="Max">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "setting the placeholder" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" placeholder="placeholder-text" />
        """
      end

    assert html =~ ~r/placeholder="placeholder-text"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_name" name="user[name]" type="text">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="color" value="Max" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" id="username" name="username" />
        """
      end

    assert html =~ """
           <input id="username" name="username" type="text">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <TextInput form="user" field="name" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_name" name="user[name]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="text">
           """
  end
end

defmodule Surface.Components.Form.TextInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Input
  alias Surface.Components.Form.TextInput

  test ":default_class config" do
    using_config TextInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <TextInput/>
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
          <TextInput/>
          """
        end

      assert html =~ ~r/class="inherited_default_class"/
    end
  end

  test ":default_class config overrides inherited :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      using_config TextInput, default_class: "default_class" do
        html =
          render_surface do
            ~F"""
            <TextInput/>
            """
          end

        assert html =~ ~r/class="default_class"/
      end
    end
  end
end
