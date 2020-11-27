defmodule Surface.Components.FormTest do
  use ExUnit.Case, async: true

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.TextInput, warn: false

  import ComponentTestHelper

  defmodule ViewWithForm do
    use Surface.LiveView

    data changeset, :any

    def render(assigns) do
      ~H"""
      <Form for={{ @changeset }} action="#" csrf_token="test" as={{ :user }} :let={{ form: f }}>
        <TextInput field="name" />
        {{ Enum.map(Keyword.get_values(f.source.errors, :name), fn {msg, _opts} -> ["Name ", msg] end) }}
      </Form>
      """
    end

    def mount(_params, session, socket) do
      {:ok, assign(socket, changeset: session["changeset"])}
    end
  end

  test "form as an atom" do
    code =
      quote do
        ~H"""
        <Form for={{:user}} action="#" csrf_token="test">
        </Form>
        """
      end

    assert render_live(code) =~ """
           <form action="#" method="post"><input name="_csrf_token" type="hidden" value="test"/></form>
           """
  end

  test "form with a text input using context" do
    code =
      quote do
        ~H"""
        <Form for={{:user}} action="#" csrf_token="test">
          <TextInput field="name" />
        </Form>
        """
      end

    assert render_live(code) =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           <input id="user_name" name="user[name]" type="text"/>\
           </form>
           """
  end

  test "form with form_for/4 opts as props" do
    code =
      quote do
        ~H"""
        <Form for={{:user}} action="#" csrf_token="test">
          <TextInput field="name" />
        </Form>
        """
      end

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
    code =
      quote do
        ~H"""
        <Form for={{:user}} action="#" change="change" submit="sumit">
        </Form>
        """
      end

    assert render_live(code) =~ """
           <form action="#" method="post" phx-change="change" phx-submit="sumit">\
           """
  end

  test "form exposes the generated form instance" do
    assigns = %{
      "changeset" =>
        Ecto.Changeset.cast(
          {%{}, %{name: :string}},
          %{name: 123},
          [:name]
        )
    }

    assert render_live(ViewWithForm, assigns) =~ ~r/Name is invalid/
  end
end
