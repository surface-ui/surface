defmodule Surface.Components.FieldTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.{Field, TextInput}, warn: false

  import ComponentTestHelper

  test "creates a wrapping <div> for the field's content" do
    code = """
    <Field name="name">
      Hi
    </Field>
    """

    assert render_live(code) =~ """
           <div class="">
             Hi
           </div>
           """
  end

  test "property class" do
    code = """
    <Field name="name" class={{ :field }}>
      Hi
    </Field>
    """

    assert render_live(code) =~ """
           <div class="field">
             Hi
           </div>
           """
  end

  test "sets the provided field into the context" do
    code = """
    <Field name="my_field">
      <TextInput form="my_form"/>
    </Field>
    """

    assert render_live(code) =~ ~S(name="my_form[my_field]")
  end
end

defmodule Surface.Components.Form.FieldConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.Field, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config Field, default_class: "default_class" do
      code = """
      <Field name="name">Hi</Field>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
