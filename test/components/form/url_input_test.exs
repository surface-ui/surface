defmodule Surface.Components.Form.UrlInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper

  alias Surface.Components.Form.UrlInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="website" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_website" name="user[website]" type="url"/>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="website" value="https://github.com/msaraiva/surface" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_website" name="user[website]" type="url" value="https://github.com/msaraiva/surface"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="website" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="website" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="website" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="user_website" name="user[website]" type="url"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="color" value="https://github.com/msaraiva/surface" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="url" value="https://github.com/msaraiva/surface"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="color" value="https://github.com/msaraiva/surface" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="url" value="https://github.com/msaraiva/surface"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="color" value="https://github.com/msaraiva/surface" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="url" value="https://github.com/msaraiva/surface"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="color" value="https://github.com/msaraiva/surface" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="url" value="https://github.com/msaraiva/surface"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="color" value="https://github.com/msaraiva/surface" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="url" value="https://github.com/msaraiva/surface"/>
           """
  end

  test "setting id and name through props" do
    code =
      quote do
        ~H"""
        <UrlInput form="user" field="uri" id="website" name="website" />
        """
      end

    assert render_live(code) =~ """
           <input id="website" name="website" type="url"/>
           """
  end
end

defmodule Surface.Components.Form.UrlInputConfigTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.UrlInput, warn: false

  test ":default_class config" do
    using_config UrlInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <UrlInput/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
