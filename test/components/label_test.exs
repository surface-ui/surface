defmodule Surface.Components.LabelTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.{Field, Label}, warn: false

  import ComponentTestHelper

  test "generates a <label> passing any opts to the underlying label/3" do
    code = """
    <Label opts={{ id: "my_id" }}/>
    """

    assert render_live(code) =~ ~r[<label (.+) id="my_id">(.+)</label>]
  end

  test "property class" do
    code = """
    <Label class={{ :label }}/>
    """

    assert render_live(code) =~ ~S(class="label")
  end

  test "property multiple classes" do
    code = """
    <Label class={{ :label, :primary }}/>
    """

    assert render_live(code) =~ ~S(class="label primary")
  end

  test "properties form and field" do
    code = """
    <Label form="user" field="name"/>
    """

    assert render_live(code) =~ ~S(<label for="user_name">Name</label>)
  end

  test "use context's form and field by default" do
    code = """
    <Form for={{ :user }}>
      <Field name="name">
        <Label/>
      </Field>
    </Form>
    """

    assert render_live(code) =~ ~S(<label for="user_name">Name</label>)
  end
end

defmodule Surface.Components.Form.LabelConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.Label, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config Label, default_class: "default_class" do
      code = """
      <Label/>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
