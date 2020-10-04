defmodule Surface.Components.Form.Inputs do
  @moduledoc """
  A wrapper for `Phoenix.HTML.Form.html.inputs_for/3`.

  Additionally, adds the generated form instance that is returned by `inputs_for/3`
  into the context, making it available to any child input.
  """

  use Surface.Component

  import Phoenix.HTML.Form

  @doc """
  The parent form.

  It should either be a `Phoenix.HTML.Form` emitted by `form_for` or an atom.
  """
  prop form, :form

  @doc """
  The name of the field related to the child inputs.
  """
  prop for, :atom

  @doc """
  Extra options for `inputs_for/3`.

  See `Phoenix.HTML.Form.html.inputs_for/4` for the available options.
  """
  prop opts, :keyword, default: []

  @doc "The code containing the input controls"
  slot default, props: [:form]

  def render(assigns) do
    ~H"""
    <Context get={{ Surface.Components.Form, form: form }}>
      <Context
        :for={{ f <- inputs_for(@form || form, @for, @opts) }}
        put={{ Surface.Components.Form, form: f }}>
        <slot :props={{ form: f }}/>
      </Context>
    </Context>
    """
  end
end
