defmodule Surface.Components.FieldContextTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form.{FieldContext, TextInput}, warn: false

  import ComponentTestHelper

  test "sets the provided field into the context" do
    code = """
    <FieldContext name="my_field">
      <TextInput form="my_form"/>
    </FieldContext>
    """

    assert render_live(code) =~ ~S(name="my_form[my_field]")
  end
end
