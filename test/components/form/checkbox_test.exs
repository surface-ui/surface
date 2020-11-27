defmodule Surface.Components.Form.CheckboxTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.Checkbox, warn: false

  import ComponentTestHelper

  test "checkbox" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_admin" name="user[admin]" type="checkbox" value="true"/>
           """
  end

  test "with form context" do
    code =
      quote do
        ~H"""
        <Form for={{ :user }} csrf_token="test">
          <Checkbox field={{ :admin }} />
        </Form>
        """
      end

    assert render_live(code) =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           <input name="user[admin]" type="hidden" value="false"/>\
           <input id="user_admin" name="user[admin]" type="checkbox" value="true"/>\
           </form>
           """
  end

  test "setting the class" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" class="checkbox" />
        """
      end

    assert render_live(code) =~ ~r/class="checkbox"/
  end

  test "setting multiple classes" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" class="checkbox primary" />
        """
      end

    assert render_live(code) =~ ~r/class="checkbox primary"/
  end

  test "passing other options" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" checked_value="admin"/>
        """
      end

    assert render_live(code) =~ """
           <input id="user_admin" name="user[admin]" type="checkbox" value="admin"/>
           """
  end

  test "blur event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" blur="my_blur" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_admin" name="user[admin]" phx-blur="my_blur" type="checkbox" value="true"/>
           """
  end

  test "focus event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" focus="my_focus" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_admin" name="user[admin]" phx-focus="my_focus" type="checkbox" value="true"/>
           """
  end

  test "capture click event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" capture_click="my_click" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_admin" name="user[admin]" phx-capture-click="my_click" type="checkbox" value="true"/>
           """
  end

  test "keydown event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" keydown="my_keydown" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_admin" name="user[admin]" phx-keydown="my_keydown" type="checkbox" value="true"/>
           """
  end

  test "keyup event with parent live view as target" do
    code =
      quote do
        ~H"""
        <Checkbox form="user" field="admin" keyup="my_keyup" />
        """
      end

    assert render_live(code) =~ """
           <input id="user_admin" name="user[admin]" phx-keyup="my_keyup" type="checkbox" value="true"/>
           """
  end
end

defmodule Surface.Components.Form.CheckboxConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.Checkbox, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config Checkbox, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <Checkbox />
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
