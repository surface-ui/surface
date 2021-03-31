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

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" blur="my_blur" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]" phx-blur="my_blur">
           </textarea>
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" focus="my_focus" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]" phx-focus="my_focus">
           </textarea>
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" capture_click="my_click" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]" phx-capture-click="my_click">
           </textarea>
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]" phx-keydown="my_keydown">
           </textarea>
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <TextArea form="user" field="summary" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <textarea id="user_summary" name="user[summary]" phx-keyup="my_keyup">
           </textarea>
           """
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
