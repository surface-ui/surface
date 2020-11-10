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

    changeset =
      {%{}, %{name: :string}}
      |> Ecto.Changeset.cast(%{name: "myname"}, [:name])
      |> Ecto.Changeset.add_error(:name, "is already taken")
      |> Ecto.Changeset.add_error(:name, "another test error")
      # Simulate that form submission already occurred so that error message will display
      |> Map.put(:action, :insert)

    %{changeset: changeset}
  end

  test "multiple error messages", %{changeset: changeset} do
    assigns = %{changeset: changeset}

    code =
      quote do
        ~H"""
        <Form for={{@changeset}} opts={{ as: :user }}>
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

  test "prop phx_feedback_for", %{changeset: changeset} do
    assigns = %{changeset: changeset}

    code =
      quote do
        ~H"""
        <Form for={{@changeset}} opts={{ as: :user }}>
          <Field name="name">
            <TextInput opts={{ id: "test-id" }} />
            <ErrorTag phx_feedback_for="test-id" />
          </Field>
        </Form>
        """
      end

    assert render_live(code, assigns) =~
             "<span phx-feedback-for=\"test-id\">is already taken</span>"

    assert render_live(code, assigns) =~
             "<input id=\"test-id\""
  end

  test "prop class", %{changeset: changeset} do
    assigns = %{changeset: changeset}

    code =
      quote do
        ~H"""
        <Form for={{@changeset}} opts={{ as: :user }}>
          <Field name="name">
            <TextInput />
            <ErrorTag class="test-class" />
          </Field>
        </Form>
        """
      end

    assert render_live(code, assigns) =~
             "<span class=\"test-class\" phx-feedback-for=\"user_name\">is already taken</span>"
  end

  test "no changeset shows no errors" do
    code =
      quote do
        ~H"""
        <Form for={{ :user }}>
          <Field name="name">
            <TextInput />
            <ErrorTag />
          </Field>
        </Form>
        """
      end

    # The error tags are displayed as spans, so this demonstrates that none were rendered
    refute render_live(code) =~ "<span"
  end
end
