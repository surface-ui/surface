defmodule Surface.Components.Form.EmailInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form.EmailInput, warn: false

  test "empty input" do
    code = """
    <EmailInput form="user" field="email" />
    """

    assert render_live(code) =~ """
           <input id="user_email" name="user[email]" type="email"/>
           """
  end

  test "setting the value" do
    code = """
    <EmailInput form="user" field="email" value="admin@gmail.com" />
    """

    assert render_live(code) =~ """
           <input id="user_email" name="user[email]" type="email" value="admin@gmail.com"/>
           """
  end

  test "setting the class" do
    code = """
    <EmailInput form="user" field="email" value="admin@gmail.com" class="input" />
    """

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code = """
    <EmailInput form="user" field="email" value="admin@gmail.com" class="input primary" />
    """

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code = """
    <EmailInput form="user" field="email" opts={{ id: "myid", autofocus: "autofocus" }} />
    """

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="user[email]" type="email"/>
           """
  end

  test "blur event with parent live view as target" do
    code = """
    <EmailInput form="user" field="color" value="admin@gmail.com" blur="my_blur" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="email" value="admin@gmail.com"/>
           """
  end

  test "focus event with parent live view as target" do
    code = """
    <EmailInput form="user" field="color" value="admin@gmail.com" focus="my_focus" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="email" value="admin@gmail.com"/>
           """
  end

  test "capture click event with parent live view as target" do
    code = """
    <EmailInput form="user" field="color" value="admin@gmail.com" capture_click="my_click" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="email" value="admin@gmail.com"/>
           """
  end

  test "keydown event with parent live view as target" do
    code = """
    <EmailInput form="user" field="color" value="admin@gmail.com" keydown="my_keydown" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="email" value="admin@gmail.com"/>
           """
  end

  test "keyup event with parent live view as target" do
    code = """
    <EmailInput form="user" field="color" value="admin@gmail.com" keyup="my_keyup" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="email" value="admin@gmail.com"/>
           """
  end
end

defmodule Surface.Components.Form.EmailInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.EmailInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config EmailInput, default_class: "default_class" do
      code = """
      <EmailInput/>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
