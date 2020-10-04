defmodule Surface.Components.Form.HiddenInputs do
  @moduledoc """
  A wrapper for `Phoenix.HTML.Form.html.hidden_inputs_for/1`.

  Generates hidden inputs for the given form.
  """

  use Surface.Component

  import Phoenix.HTML.Form
  alias Surface.Components.Form.Input.InputContext

  @doc """
  The form.

  It should either be a `Phoenix.HTML.Form` emitted by `form_for`, `inputs_for` or an atom.
  """
  prop for, :form

  def render(assigns) do
    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form }}>
      {{ hidden_inputs_for(form) }}
    </InputContext>
    """
  end
end
