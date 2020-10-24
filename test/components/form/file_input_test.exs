defmodule Surface.Components.Form.FileInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.FileInput, warn: false

  test "empty input" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_picture" name="user[picture]" type="file"/>
           """
  end

  test "with form context" do
    code =
      quote do
        ~H"""
        <Form for={{ :user }} opts={{ csrf_token: "test", multipart: true }}>
          <FileInput field={{ :picture }} />
        </Form>
        """
      end

    assert render_live(code) =~ """
           <form action="#" enctype="multipart/form-data" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           <input id="user_picture" name="user[picture]" type="file"/>\
           </form>
           """
  end

  test "setting the value" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" value="path/to/file" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_picture" name="user[picture]" type="file" value="path/to/file"/>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" class="input" />
        """
      end

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" class="input primary" />
        """
      end

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" opts={{ id: "myid", autofocus: "autofocus" }} />
        """
      end

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[picture]" type="file"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_picture" name="user[picture]" phx-blur="my_blur" type="file"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_picture" name="user[picture]" phx-focus="my_focus" type="file"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_picture" name="user[picture]" phx-capture-click="my_click" type="file"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_picture" name="user[picture]" phx-keydown="my_keydown" type="file"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <FileInput form="user" field="picture" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_picture" name="user[picture]" phx-keyup="my_keyup" type="file"/>
           """
  end
end

defmodule Surface.Components.Form.FileInputConfigTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.FileInput, warn: false

  test ":default_class config" do
    using_config FileInput, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <FileInput />
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
