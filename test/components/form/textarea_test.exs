defmodule Surface.Components.Form.TextAreaTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.TextArea, warn: false

  import ComponentTestHelper

  test "empty textarea" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]">\n</textarea>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" value="some content" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]">\nsome content</textarea>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <textarea autofocus="autofocus" id="user_summary" name="user[summary]">\n</textarea>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-blur="my_blur">\n</textarea>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-focus="my_focus">\n</textarea>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-capture-click="my_click">\n</textarea>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-keydown="my_keydown">\n</textarea>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-keyup="my_keyup">\n</textarea>
           """
  end

  test "setting id and name through props" do
    code =
      quote do
        ~H"""
        <TextArea form="user" field="summary" id="blog_summary" name="blog_summary" />
        """
      end

    assert render_live(code) =~ """
           <textarea id="blog_summary" name="blog_summary">\n</textarea>
           """
  end
end

defmodule Surface.Components.Form.TextAreaConfigTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.TextArea, warn: false

  test ":default_class config" do
    using_config TextArea, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <TextArea/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
