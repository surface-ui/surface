defmodule Surface.Components.Form.ErrorTagTest.Common do
  @moduledoc """
  Common functions used by both ErrorTagTest and ErrorTagSyncTest
  """

  def changeset do
    {%{}, %{name: :string}}
    |> Ecto.Changeset.cast(%{name: "myname"}, [:name])
    |> Ecto.Changeset.add_error(:name, "is already taken")
    |> Ecto.Changeset.add_error(:name, "another test error")
    # Simulate that form submission already occurred so that error message will display
    |> Map.put(:action, :insert)
  end
end

defmodule Surface.Components.Form.ErrorTagTest do
  use ExUnit.Case, async: true

  import Surface
  import ComponentTestHelper

  alias Surface.Components.Form.ErrorTagTest.Common
  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.Field, warn: false
  alias Surface.Components.Form.ErrorTag, warn: false

  setup do
    %{changeset: Common.changeset()}
  end

  test "multiple error messages", %{changeset: changeset} do
    assigns = %{changeset: changeset}

    code =
      quote do
        ~H"""
        <Form for={{@changeset}} opts={{ as: :user }}>
          <Field name="name">
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
            <ErrorTag phx_feedback_for="test-id" />
          </Field>
        </Form>
        """
      end

    assert render_live(code, assigns) =~
             "<span phx-feedback-for=\"test-id\">is already taken</span>"
  end

  test "prop class", %{changeset: changeset} do
    assigns = %{changeset: changeset}

    code =
      quote do
        ~H"""
        <Form for={{@changeset}} opts={{ as: :user }}>
          <Field name="name">
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
            <ErrorTag />
          </Field>
        </Form>
        """
      end

    # The error tags are displayed as spans, so this demonstrates that none were rendered
    refute render_live(code) =~ "<span"
  end
end

defmodule Surface.Components.Form.ErrorTagSyncTest do
  use ExUnit.Case

  import ComponentTestHelper
  alias Surface.Components.Form.ErrorTagTest.Common
  alias Surface.Components.Form, warn: false
  alias Surface.Components.Form.Field, warn: false
  alias Surface.Components.Form.ErrorTag, warn: false

  setup do
    %{changeset: Common.changeset()}
  end

  test "translator from config", %{changeset: changeset} do
    using_config ErrorTag,
      translator: {Surface.Components.Form.ErrorTagSyncTest, :config_translate_error} do
      assigns = %{changeset: changeset}

      code =
        quote do
          ~H"""
          <Form for={{@changeset}} opts={{ as: :user }}>
            <Field name="name">
              <ErrorTag />
            </Field>
          </Form>
          """
        end

      assert render_live(code, assigns) =~
               "<span phx-feedback-for=\"user_name\">translated by config translator</span>"
    end
  end

  test "prop translator overrides config and fallback", %{changeset: changeset} do
    using_config ErrorTag,
      translator: {Surface.Components.Form.ErrorTagSyncTest, :config_translate_error} do
      assigns = %{changeset: changeset}

      code =
        quote do
          ~H"""
          <Form for={{@changeset}} opts={{ as: :user }}>
            <Field name="name">
              <ErrorTag translator={{ fn _ -> "translated by prop translator" end }} />
            </Field>
          </Form>
          """
        end

      assert render_live(code, assigns) =~
               "<span phx-feedback-for=\"user_name\">translated by prop translator</span>"

      refute render_live(code, assigns) =~
               "<span phx-feedback-for=\"user_name\">translated by config translator</span>"
    end
  end

  def config_translate_error({_msg, _opts}) do
    "translated by config translator"
  end
end
