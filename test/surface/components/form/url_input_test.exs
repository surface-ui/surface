defmodule Surface.Components.Form.UrlInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.UrlInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="website" />
        """
      end

    assert html =~ """
           <input id="user_website" name="user[website]" type="url">
           """
  end

  test "input with atom field" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field={:website} />
        """
      end

    assert html =~ """
           <input id="user_website" name="user[website]" type="url">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="website" value="https://github.com/surface-ui/surface" />
        """
      end

    assert html =~ """
           <input id="user_website" name="user[website]" type="url" value="https://github.com/surface-ui/surface">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="website" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="website" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="website" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_website" name="user[website]" type="url">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="color" value="https://github.com/surface-ui/surface" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="uri" id="website" name="website" />
        """
      end

    assert html =~ """
           <input id="website" name="website" type="url">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <UrlInput form="user" field="website" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_website" name="user[website]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="url">
           """
  end
end

defmodule Surface.Components.Form.UrlInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.UrlInput

  test ":default_class config" do
    using_config UrlInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <UrlInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
