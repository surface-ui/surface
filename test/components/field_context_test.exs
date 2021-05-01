defmodule Surface.Components.FieldContextTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.{FieldContext, TextInput}

  test "sets the provided field into the context as :string" do
    html =
      render_surface do
        ~H"""
        <FieldContext name="my_field">
          <TextInput form="my_form"/>
        </FieldContext>
        """
      end

    assert html =~ ~S(name="my_form[my_field]")
  end

  test "sets the provided field into the context as :atom" do
    html =
      render_surface do
        ~H"""
        <FieldContext name={{ :my_field }}>
          <TextInput form="my_form"/>
        </FieldContext>
        """
      end

    assert html =~ ~S(name="my_form[my_field]")
  end
end
