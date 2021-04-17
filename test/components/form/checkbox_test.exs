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

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Checkbox form="user" field="admin"
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
