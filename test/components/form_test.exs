defmodule Surface.Components.FormTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.TextInput

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
    html =
      render_surface do
        ~H"""
        <Form for={{:user}} action="#" csrf_token="test">
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
           </form>
           """
  end

  test "form with a text input using context" do
    html =
      render_surface do
        ~H"""
        <Form for={{:user}} action="#" csrf_token="test">
          <TextInput field="name" />
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
             <input id="user_name" name="user[name]" type="text">
           </form>
           """
  end

  test "form with form_for/4 opts as props" do
    html =
      render_surface do
        ~H"""
        <Form for={{:user}} action="#" csrf_token="test">
          <TextInput field="name" />
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test">
             <input id="user_name" name="user[name]" type="text">
           </form>
           """
  end

  test "form as a changeset", %{conn: conn} do
    assigns = %{
      "changeset" =>
        Ecto.Changeset.cast(
          {%{}, %{name: :string}},
          %{name: "myname"},
          [:name]
        )
    }

    {:ok, _view, html} = live_isolated(conn, ViewWithForm, session: assigns)

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" value="test"/>\
           <input id="user_name" name="user[name]" type="text" value="myname"/>\
           </form>\
           """
  end

  test "form with events" do
    html =
      render_surface do
        ~H"""
        <Form for={{:user}} action="#" change="change" submit="sumit">
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post" phx-change="change" phx-submit="sumit">\
           """
  end

  test "form exposes the generated form instance", %{conn: conn} do
    assigns = %{
      "changeset" =>
        Ecto.Changeset.cast(
          {%{}, %{name: :string}},
          %{name: 123},
          [:name]
        )
    }

    {:ok, _view, html} = live_isolated(conn, ViewWithForm, session: assigns)

    assert html =~ ~r/Name is invalid/
  end
end
