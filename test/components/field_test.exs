defmodule Surface.Components.FieldTest do
  use ExUnit.Case

  alias Surface.Components.Form.{Field, TextInput}, warn: false

  import ComponentTestHelper

  test "creates a wrapping <div> for the field's content" do
    code = """
    <Field field="name">
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
    <Field field="name" class={{ :field }}>
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
    <Field field="my_field">
      <TextInput form="my_form"/>
    </Field>
    """

    assert render_live(code) =~ ~S(name="my_form[my_field]")
  end
end
