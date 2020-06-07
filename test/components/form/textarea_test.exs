defmodule Surface.Components.Form.TextAreaTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.TextArea, warn: false

  import ComponentTestHelper

  test "empty textarea" do
    code = """
    <TextArea form="user" field="summary" />
    """

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]">\n</textarea>
           """
  end

  test "setting the value" do
    code = """
    <TextArea form="user" field="summary" value="some content" />
    """

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]">\nsome content</textarea>
           """
  end

  test "passing other options" do
    code = """
    <TextArea form="user" field="summary" opts={{ id: "myid", autofocus: "autofocus" }} />
    """

    assert render_live(code) =~ """
           <textarea autofocus="autofocus" id="myid" name="user[summary]">\n</textarea>
           """
  end

  test "blur event with parent live view as target" do
    code = """
    <TextArea form="user" field="summary" blur="my_blur" />
    """

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-blur="my_blur">\n</textarea>
           """
  end

  test "focus event with parent live view as target" do
    code = """
    <TextArea form="user" field="summary" focus="my_focus" />
    """

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-focus="my_focus">\n</textarea>
           """
  end

  test "capture click event with parent live view as target" do
    code = """
    <TextArea form="user" field="summary" capture_click="my_click" />
    """

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-capture-click="my_click">\n</textarea>
           """
  end

  test "keydown event with parent live view as target" do
    code = """
    <TextArea form="user" field="summary" keydown="my_keydown" />
    """

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-keydown="my_keydown">\n</textarea>
           """
  end

  test "keyup event with parent live view as target" do
    code = """
    <TextArea form="user" field="summary" keyup="my_keyup" />
    """

    assert render_live(code) =~ """
           <textarea id="user_summary" name="user[summary]" phx-keyup="my_keyup">\n</textarea>
           """
  end
end

defmodule Surface.Components.Form.TextAreaConfigTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.TextArea, warn: false

  test ":default_class config" do
    using_config TextArea, default_class: "default_class" do
      code = """
      <TextArea/>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
