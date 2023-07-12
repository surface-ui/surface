defmodule Surface.Components.FormTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form
  alias Surface.Components.Form.TextInput

  defmodule User do
    use Ecto.Schema

    schema "user" do
      field(:name, :string)
    end
  end

  defmodule ViewWithForm do
    use Surface.LiveView

    data changeset, :any

    def render(assigns) do
      ~F"""
      <Form for={@changeset} action="#" csrf_token="test" as={:user} :let={form: f}>
        <TextInput field={:name} />
        {Enum.map(Keyword.get_values(f.source.errors, :name), fn {msg, _opts} -> ["Name ", msg] end)}
      </Form>
      """
    end

    def mount(_params, session, socket) do
      changeset =
        Ecto.Changeset.cast(
          {%{}, %{name: :string}},
          session["changeset_data"],
          [:name]
        )

      {:ok, assign(socket, changeset: changeset)}
    end
  end

  defmodule ViewWithFormWithMethodPut do
    use Surface.LiveView

    def render(assigns) do
      ~F"""
      <Form for={%{}} action="#" csrf_token="test" as={:user} method="put">
        <TextInput field={:name} />
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
        ~F"""
        <Form for={%{}} as={:user} action="#" csrf_token="test">
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
           </form>
           """
  end

  test "form with a text input using context" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:user} action="#" csrf_token="test">
          <TextInput field="name" />
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
             <input id="user_name" name="user[name]" type="text">
           </form>
           """
  end

  test "form with form_for/4 opts as props" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:user} action="#" csrf_token="test">
          <TextInput field="name" />
        </Form>
        """
      end

    assert html =~ """
           <form action="#" method="post">
               <input name="_csrf_token" type="hidden" hidden value="test">
             <input id="user_name" name="user[name]" type="text">
           </form>
           """
  end

  test "form as a changeset", %{conn: conn} do
    session = %{"changeset_data" => %{name: "myname"}}

    {:ok, _view, html} = live_isolated(conn, ViewWithForm, session: session)

    assert html =~ """
           <form action="#" method="post">\
           <input name="_csrf_token" type="hidden" hidden="hidden" value="test"/>\
           <input id="user_name" name="user[name]" type="text" value="myname"/>\
           </form>\
           """
  end

  test "form with events" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:user} action="#" change="change" submit="submit" auto_recover="recover">
        </Form>
        """
      end

    # Assert: <form action="#" method="post" phx-auto-recover="recover" phx-change="change" phx-submit="submit">
    doc = parse_document!(html)
    assert attribute(doc, "phx-change") == ["change"]
    assert attribute(doc, "phx-submit") == ["submit"]
    assert attribute(doc, "phx-auto-recover") == ["recover"]
  end

  test "form exposes the generated form instance", %{conn: conn} do
    session = %{"changeset_data" => %{name: 123}}

    {:ok, _view, html} = live_isolated(conn, ViewWithForm, session: session)

    assert html =~ ~r/Name is invalid/
  end

  test "form generates method input for prop" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:user} action="#" method="put" csrf_token="test">
        </Form>
        """
      end

    assert html =~ ~s(<input name="_method" type="hidden" hidden value="put">)
  end

  test "form generates method input for changeset", %{conn: conn} do
    {:ok, _view, html} = live_isolated(conn, ViewWithFormWithMethodPut)

    assert html =~ ~s(><input name="_method" type="hidden" hidden="hidden" value="put"/>)
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:user} action="#" class="form">
        </Form>
        """
      end

    assert html =~ ~r/class="form"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:user} action="#" class="form form-user">
        </Form>
        """
      end

    assert html =~ ~r/class="form form-user"/
  end

  test "setting multiple classes as css_class" do
    html =
      render_surface do
        ~F"""
        <Form for={%{}} as={:user} action="#" class={"form", "form-user": true}>
        </Form>
        """
      end

    assert html =~ ~r/class="form form-user"/
  end

  test "setting the trigger_action" do
    html = render_surface(do: ~F[<Form for={%{}} as={:user} />])
    refute html =~ ~r/phx-trigger-action/

    html = render_surface(do: ~F[<Form for={%{}} as={:user} trigger_action={true} />])
    assert html =~ ~r/phx-trigger-action/
  end
end

defmodule Surface.Components.Form.FormTestConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form

  test ":default_class config" do
    using_config Form, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <Form for={%{}} as={:user} action="#" />
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
