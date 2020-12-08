defmodule Surface.Components.Form.FileInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.FileInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" />
        """
      end

    assert html =~ """
           <input id="user_picture" name="user[picture]" type="file">
           """
  end

  test "with form context" do
    html =
      render_surface do
        ~H"""
        <Form for={{ :user }} csrf_token="test" multipart={{true}} >
          <FileInput field={{ :picture }} />
        </Form>
        """
      end

    assert html =~ """
           <form action="#" enctype="multipart/form-data" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
             <input id="user_picture" name="user[picture]" type="file">
           </form>
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" value="path/to/file" />
        """
      end

    assert html =~ """
           <input id="user_picture" name="user[picture]" type="file" value="path/to/file">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="user_picture" name="user[picture]" type="file">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_picture" name="user[picture]" phx-blur="my_blur" type="file">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_picture" name="user[picture]" phx-focus="my_focus" type="file">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_picture" name="user[picture]" phx-capture-click="my_click" type="file">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_picture" name="user[picture]" phx-keydown="my_keydown" type="file">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_picture" name="user[picture]" phx-keyup="my_keyup" type="file">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <FileInput form="user" field="picture" id="image" name="image" />
        """
      end

    assert html =~ """
           <input id="image" name="image" type="file">
           """
  end
end

defmodule Surface.Components.Form.FileInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.FileInput

  test ":default_class config" do
    using_config FileInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <FileInput />
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
