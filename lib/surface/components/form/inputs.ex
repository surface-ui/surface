defmodule Surface.Components.Form.Inputs do
  @moduledoc """
  A wrapper for `Phoenix.HTML.Form.html.inputs_for/3`.

  Additionally, adds the generated form instance that is returned by `inputs_for/3`
  into the context, making it available to any child input.
  """

  use Surface.Component

  import Phoenix.HTML.Form
  import Surface.Components.Form.Utils

  @doc """
  The parent form.

  It should either be a `Phoenix.HTML.Form` emitted by `form_for` or an atom.
  """
  property form, :form

  @doc """
  The name of the field related to the child inputs.
  """
  property for, :atom

  @doc """
  Extra options for `inputs_for/3`.

  See `Phoenix.HTML.Form.html.inputs_for/4` for the available options.
  """
  property opts, :keyword, default: []

  @doc "The code containing the input controls"
  slot default, props: [:form]

  def render(assigns) do
    ~H"""
    <div :for={{ f <- inputs_for(get_form(assigns), @for, @opts) }}>
      <Context set={{ :form, f, scope: Surface.Components.Form }}>
        <slot :props={{ form: f }}/>
      </Context>
    </div>
    """
  end
end
