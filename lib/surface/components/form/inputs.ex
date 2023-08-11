defmodule Surface.Components.Form.Inputs do
  @moduledoc """
  A wrapper for `Phoenix.HTML.Form.html.inputs_for/3`.

  Additionally, adds the generated form instance that is returned by `inputs_for/3`
  into the context, making it available to any child input.
  """

  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.Field

  @doc """
  The parent form.

  It should either be a `Phoenix.HTML.Form` emitted by `form_for` or an atom.
  """
  prop form, :form, from_context: {Form, :form}

  @doc """
  An atom or string representing the field related to the child inputs.
  """
  prop for, :any, from_context: {Field, :field}

  @doc """
  Extra options for `inputs_for/1`.

  See `Phoenix.Component.inputs_for/1` for the available options.
  """
  prop opts, :keyword, default: []

  @doc "The code containing the input controls"
  slot default, arg: %{form: :form, index: :integer}

  data field, :any

  def render(assigns) do
    ~F"""
    <.inputs_for :let={nested_form} field={@form[@for || @field]} {...@opts}>
      <#slot {@default, form: nested_form, index: nested_form.index } context_put={__MODULE__, form: nested_form} />
    </.inputs_for>
    """
  end
end
