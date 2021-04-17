defmodule Surface.Components.Form.UrlInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.UrlInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
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
        ~H"""
        <UrlInput form="user" field={{ :website }} />
        """
      end

    assert html =~ """
           <input id="user_website" name="user[website]" type="url">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
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
        ~H"""
        <UrlInput form="user" field="website" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <UrlInput form="user" field="website" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <UrlInput form="user" field="website" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_website" name="user[website]" type="url">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <UrlInput form="user" field="color" value="https://github.com/surface-ui/surface"
          capture_click="my_capture_click"
          click="my_click"
          window_focus="my_window_focus"
          window_blur="my_window_blur"
          focus="my_focus"
          blur="my_blur"
          window_keyup="my_window_keyup"
          window_keydown="my_window_keydown"
          keyup="my_keyup"
          keydown="my_keydown"
        />
        """
      end

    assert html =~ ~s(phx-capture-click="my_capture_click")
    assert html =~ ~s(phx-click="my_click")
    assert html =~ ~s(phx-window-focus="my_window_focus")
    assert html =~ ~s(phx-window-blur="my_window_blur")
    assert html =~ ~s(phx-focus="my_focus")
    assert html =~ ~s(phx-blur="my_blur")
    assert html =~ ~s(phx-window-keyup="my_window_keyup")
    assert html =~ ~s(phx-window-keydown="my_window_keydown")
    assert html =~ ~s(phx-keyup="my_keyup")
    assert html =~ ~s(phx-keydown="my_keydown")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <UrlInput form="user" field="uri" id="website" name="website" />
        """
      end

    assert html =~ """
           <input id="website" name="website" type="url">
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
          ~H"""
          <UrlInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
