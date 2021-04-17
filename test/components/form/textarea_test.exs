defmodule Surface.Components.Form.TextAreaTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.TextArea

  test "empty textarea" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]">
           </textarea>
           """
  end

  test "textarea with atom field" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field={{ :summary }} />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]">
           </textarea>
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" value="some content" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]">
           some content</textarea>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <textarea autofocus="autofocus" id="user_summary" name="user[summary]">
           </textarea>
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary"
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
        <TextArea form="user" field="summary" id="blog_summary" name="blog_summary" />
        """
      end

    assert html =~ """
           <textarea id="blog_summary" name="blog_summary">
           </textarea>
           """
  end
end

defmodule Surface.Components.Form.TextAreaConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.TextArea

  test ":default_class config" do
    using_config TextArea, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <TextArea/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
