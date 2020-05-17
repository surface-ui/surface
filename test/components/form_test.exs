defmodule Surface.Components.FormTest do
  use ExUnit.Case

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.TextInput, warn: false

  import ComponentTestHelper

  defmodule ViewWithForm do
    use Surface.LiveView

    def render(assigns) do
      ~H"""
      <Form for={{ @changeset }} action="#" opts={{ csrf_token: "test", as: :user }}>
        <TextInput field="name" />
      </Form>
      """
    end

    def mount(_params, session, socket) do
      {:ok, assign(socket, changeset: session["changeset"])}
    end
  end

  test "form as an atom" do
    code = """
    <Form for={{:user}} action="#" opts={{ csrf_token: "test" }}>
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post"><input name="_csrf_token" type="hidden" value="test"/></form>
           """
  end

  test "form with a text input using context" do
    code = """
    <Form for={{:user}} action="#" opts={{ csrf_token: "test" }}>
      <TextInput field="name" />
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           <input id="user_name" name="user[name]" type="text"/>\
           </form>
           """
  end

  test "form as a changeset" do
    assigns = %{
      "changeset" =>
        Ecto.Changeset.cast(
          {%{}, %{name: :string}},
          %{name: "myname"},
          [:name]
        )
    }

    assert render_live(ViewWithForm, assigns) =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           <input id="user_name" name="user[name]" type="text" value="myname"/>\
           </form>
           """
  end

  test "form with events" do
    code = """
    <Form for={{:user}} action="#" change="change" submit="sumit">
    </Form>
    """

    assert render_live(code) =~ """
           <form action="#" method="post" phx-change="change" phx-submit="sumit">\
           """
  end
end
