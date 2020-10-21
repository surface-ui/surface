defmodule Surface.Components.FieldTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.{Field, TextInput}, warn: false

  import ComponentTestHelper

  test "sets the provided field into the context" do
    code = """
    <Field name="my_field">
      <TextInput form="my_form"/>
    </Field>
    """

    assert render_live(code) =~ ~S(name="my_form[my_field]")
  end
end
