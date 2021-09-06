defmodule Surface.Components.Form.CheckboxTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.Checkbox

  test "checkbox" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <Checkbox form="user" field={:admin} />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" type="checkbox" value="true">
           """
  end

  test "with form context" do
    html =
      render_surface do
        ~F"""
        <Form for={:user} csrf_token="test">
          <Checkbox field={:admin} />
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" value="test">
           <input name="user[admin]" type="hidden" value="false">\
           <input id="user_admin" name="user[admin]" type="checkbox" value="true">
           </form>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <Checkbox form="user" field="admin" class="checkbox" />
        """
      end

    assert html =~ ~r/class="checkbox"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <Checkbox form="user" field="admin" class="checkbox primary" />
        """
      end

    assert html =~ ~r/class="checkbox primary"/
  end

  test "passing checked value" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <Checkbox value={true}/>
        """
      end

    assert html =~ ~r/checked/

    html =
      render_surface do
        ~F"""
        <Checkbox value={false}/>
        """
      end

    refute html =~ ~r/checked/
  end

  test "setting the hidden_input" do
    html =
      render_surface do
        ~F"""
        <Checkbox hidden_input={true}/>
        """
      end

    assert html =~ ~r/hidden/

    html =
      render_surface do
        ~F"""
        <Checkbox hidden_input={false}/>
        """
      end

    refute html =~ ~r/hidden/
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <Checkbox form="user" field="admin" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <Checkbox form="user" field="admin" opts={disabled: "disabled"} />
        """
      end

    assert html =~ """
           <input disabled="disabled" id="user_admin" name="user[admin]" type="checkbox" value="true">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <Checkbox form="user" field="admin" id="is_admin" name="is_admin" />
        """
      end

    assert html =~ """
           <input id="is_admin" name="is_admin" type="checkbox" value="true">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <Checkbox form="user" field="admin" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_admin" name="user[admin]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="checkbox" value="true">
           """
  end
end

defmodule Surface.Components.Form.CheckboxConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Input
  alias Surface.Components.Form.Checkbox

  test ":default_class config" do
    using_config Checkbox, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <Checkbox />
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end

  test "component inherits :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      html =
        render_surface do
          ~F"""
          <Checkbox/>
          """
        end

      assert html =~ ~r/class="inherited_default_class"/
    end
  end

  test ":default_class config overrides inherited :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      using_config Checkbox, default_class: "default_class" do
        html =
          render_surface do
            ~F"""
            <Checkbox/>
            """
          end

        assert html =~ ~r/class="default_class"/
      end
    end
  end
end
