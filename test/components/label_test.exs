defmodule Surface.Components.LabelTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.{Field, Label}, warn: false

  import ComponentTestHelper

  test "generates a <label> passing any opts to the underlying label/3" do
    code =
      quote do
        ~H"""
        <Label opts={{ id: "my_id" }}/>
        """
      end

    assert render_live(code) =~ ~r[<label (.+) id="my_id">(.+)</label>]
  end

  test "property class" do
    code =
      quote do
        ~H"""
        <Label class={{ :label }}/>
        """
      end

    assert render_live(code) =~ ~S(class="label")
  end

  test "property multiple classes" do
    code =
      quote do
        ~H"""
        <Label class={{ :label, :primary }}/>
        """
      end

    assert render_live(code) =~ ~S(class="label primary")
  end

  test "properties form and field" do
    code =
      quote do
        ~H"""
        <Label form="user" field="name"/>
        """
      end

    assert render_live(code) =~ ~S(<label for="user_name">Name</label>)
  end

  test "use context's form and field by default" do
    code =
      quote do
        ~H"""
        <Form for={{ :user }}>
          <Field name="name">
            <Label/>
          </Field>
        </Form>
        """
      end

    assert render_live(code) =~ ~S(<label for="user_name">Name</label>)
  end
end

defmodule Surface.Components.Form.LabelConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.Label, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config Label, default_class: "default_class" do
      code =
        quote do
          ~H"""
          <Label/>
          """
        end

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
