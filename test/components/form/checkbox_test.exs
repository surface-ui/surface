defmodule Surface.Components.Form.CheckboxTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.Checkbox

  test "checkbox" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" type="checkbox" value="true">
           """
  end

  test "checkbox with atom field" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field={{ :admin }} />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" type="checkbox" value="true">
           """
  end

  test "with form context" do
    html =
      render_surface do
        ~H"""
        <Form for={{ :user }} csrf_token="test">
          <Checkbox field={{ :admin }} />
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
           <input name="user[admin]" type="hidden" value="false">\
           <input id="user_admin" name="user[admin]" type="checkbox" value="true">
           </form>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" class="checkbox" />
        """
      end

    assert html =~ ~r/class="checkbox"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" class="checkbox primary" />
        """
      end

    assert html =~ ~r/class="checkbox primary"/
  end

  test "passing checked value" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" checked_value="admin"/>
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" type="checkbox" value="admin">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <Checkbox value={{ true }}/>
        """
      end

    assert html =~ ~r/checked/

    html =
      render_surface do
        ~H"""
        <Checkbox value={{ false }}/>
        """
      end

    refute html =~ ~r/checked/
  end

  test "setting the hidden_input" do
    html =
      render_surface do
        ~H"""
        <Checkbox hidden_input={{ true }}/>
        """
      end

    assert html =~ ~r/hidden/

    html =
      render_surface do
        ~H"""
        <Checkbox hidden_input={{ false }}/>
        """
      end

    refute html =~ ~r/hidden/
  end

  test "window blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" window_blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-window-blur="my_blur" type="checkbox" value="true">
           """
  end

  test "window focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" window_focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-window-focus="my_focus" type="checkbox" value="true">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-blur="my_blur" type="checkbox" value="true">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-focus="my_focus" type="checkbox" value="true">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-capture-click="my_click" type="checkbox" value="true">
           """
  end

  test "click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-click="my_click" type="checkbox" value="true">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-keydown="my_keydown" type="checkbox" value="true">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-keyup="my_keyup" type="checkbox" value="true">
           """
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" opts={{ disabled: "disabled" }} />
        """
      end

    assert html =~ """
           <input disabled="disabled" id="user_admin" name="user[admin]" type="checkbox" value="true">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin" id="is_admin" name="is_admin" />
        """
      end

    assert html =~ """
           <input id="is_admin" name="is_admin" type="checkbox" value="true">
           """
  end
end

defmodule Surface.Components.Form.CheckboxConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Checkbox

  test ":default_class config" do
    using_config Checkbox, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <Checkbox />
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
