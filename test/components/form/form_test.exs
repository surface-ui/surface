defmodule Surface.Components.Form.FormTest do
  use ExUnit.Case

  alias Surface.Components.Form.{
    Form,
    TextInput
  }

  import ComponentTestHelper

  # Form can be changeset, conn or atom
  test "form as an atom" do
    code = """
    <Form for={{:user}} action="#" opts={{ [csrf_token: "test"] }}>
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post"><input name="_csrf_token" type="hidden" value="test"/></form>
           """
  end

  test "form with a text input using context" do
    code = """
    <Form for={{:user}} action="#" opts={{ [csrf_token: "test"] }}>
      <TextInput field="name" />
    </Form>
    """

    assert render_live(code) =~
             one_line("""
             <form action="#" method="post">
             <input name="_csrf_token" type="hidden" value="test"/>
             <input id="user_name" name="user[name]" type="text"/>
             </form>
             """)
  end

  test "form as a changeset" do
    assigns = %{
      changeset:
        Ecto.Changeset.cast(
          {%{}, %{name: :string}},
          %{name: "myname"},
          [:name]
        )
    }

    code = """
    <Form for={{ @changeset }} action="#" opts={{ [csrf_token: "test"] }}>
    </Form>
    """

    assert render_live(code, assigns) =~ """
           <form action="#" method="post"><input name="_csrf_token" type="hidden" value="test"/></form>
           """
  end

  defp one_line(multi_line_string) do
    String.replace(multi_line_string, "\n", "")
  end
end
