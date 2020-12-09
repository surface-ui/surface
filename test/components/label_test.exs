defmodule Surface.Components.LabelTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, Label}

  test "generates a <label> passing any opts to the underlying label/3" do
    html =
      render_surface do
        ~H"""
        <Label opts={{ id: "my_id" }}/>
        """
      end

    assert html =~ ~r[<label (.+) id="my_id">(.+)</label>]
  end

  test "property class" do
    html =
      render_surface do
        ~H"""
        <Label class={{ :label }}/>
        """
      end

    assert html =~ ~S(class="label")
  end

  test "property multiple classes" do
    html =
      render_surface do
        ~H"""
        <Label class={{ :label, :primary }}/>
        """
      end

    assert html =~ ~S(class="label primary")
  end

  test "properties form and field" do
    html =
      render_surface do
        ~H"""
        <Label form="user" field="name"/>
        """
      end

    assert html =~ ~S(<label for="user_name">Name</label>)
  end

  test "use context's form and field by default" do
    html =
      render_surface do
        ~H"""
        <Form for={{ :user }}>
          <Field name="name">
            <Label/>
          </Field>
        </Form>
        """
      end

    assert html =~ ~S(<label for="user_name">Name</label>)
  end
end

defmodule Surface.Components.Form.LabelConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Label

  test ":default_class config" do
    using_config Label, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <Label/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
