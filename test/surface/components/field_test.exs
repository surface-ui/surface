defmodule Surface.Components.FieldTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.{Field, TextInput}

  test "creates a wrapping <div> for the field's content" do
    html =
      render_surface do
        ~F"""
        <Field name="name">
          Hi
        </Field>
        """
      end

    assert html =~ """
           <div>
             Hi
           </div>
           """
  end

  test "property class" do
    html =
      render_surface do
        ~F"""
        <Field name="name" class={:field}>
          Hi
        </Field>
        """
      end

    assert html =~ """
           <div class="field">
             Hi
           </div>
           """
  end

  test "sets the provided field into the context" do
    html =
      render_surface do
        ~F"""
        <Field name="my_field">
          <TextInput form="my_form"/>
        </Field>
        """
      end

    assert html =~ ~S(name="my_form[my_field]")
  end
end

defmodule Surface.Components.Form.FieldConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Field

  test ":default_class config" do
    using_config Field, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <Field name="name">Hi</Field>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
