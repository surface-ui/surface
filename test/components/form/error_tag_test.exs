defmodule Surface.Components.Form.ErrorTagTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper

  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.Field, warn: false
  alias Surface.Components.Form.ErrorTag, warn: false
  alias Surface.Components.Form.TextInput, warn: false

  defmodule MyGettext do
    use Gettext, otp_app: :surface
  end

  setup do
    Application.put_env(:surface, :gettext_module, __MODULE__.MyGettext)
  end

  test "empty input" do
    assigns = %{
      changeset:
        {%{}, %{name: :string}}
        |> Ecto.Changeset.cast(%{name: "myname"}, [:name])
        |> Ecto.Changeset.add_error(:name, "is already taken")
        |> Ecto.Changeset.add_error(:name, "another test error")
        # Simulate that form submission already occurred so that error message will display
        |> Map.put(:action, :insert)
    }

    code =
      quote do
        ~H"""
        <Form for={{@changeset}} opts={{ as: :user }} action="#" change="change" submit="sumit">
          <Field name="name">
            <TextInput />
            <ErrorTag />
          </Field>
        </Form>
        """
      end

    assert render_live(code, assigns) =~
             "<span phx-feedback-for=\"user_name\">is already taken</span>"

    assert render_live(code, assigns) =~
             "<span phx-feedback-for=\"user_name\">another test error</span>"
  end
end
