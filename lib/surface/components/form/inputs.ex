defmodule Surface.Components.Form.Inputs do
  @moduledoc """
  A wrapper for `Phoenix.HTML.Form.html.inputs_for/3`.

  Additionally, adds the generated form instance that is returned by `inputs_for/3`
  into the context, making it available to any child input.
  """

  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.Field

  import Phoenix.HTML.Form

  @doc """
  The parent form.

  It should either be a `Phoenix.HTML.Form` emitted by `form_for` or an atom.
  """
  prop form, :form

  @doc """
  An atom or string representing the field related to the child inputs.
  """
  prop for, :any

  @doc """
  Extra options for `inputs_for/3`.

  See `Phoenix.HTML.Form.html.inputs_for/4` for the available options.
  """
  prop opts, :keyword, default: []

  @doc "The code containing the input controls"
  slot default, arg: %{form: :form, index: :integer}

  data field, :any

  def render(assigns) do
    assigns =
      assigns
      |> Context.maybe_copy_assign!({Form, :form})
      |> Context.copy_assign({Field, :field})

    ~F"""
    {#for {f, index}  <- Enum.with_index(inputs_for(@form, @for || @field, @opts))}
      <#slot {@default, form: f, index: index} context_put={Form, form: f}/>
    {/for}
    """
  end
end
