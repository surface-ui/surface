defmodule Surface.Components.Form.HiddenInputs do
  @moduledoc """
  A wrapper for `Phoenix.HTML.Form.html.hidden_inputs_for/1`.

  Generates hidden inputs for the given form.
  """

  use Surface.Component

  import Phoenix.HTML.Form
  import Surface.Components.Form.Utils

  @doc """
  The form.

  It should either be a `Phoenix.HTML.Form` emitted by `form_for`, `inputs_for` or an atom.
  """
  property for, :form

  def render(assigns) do
    form = get_form(assigns)

    ~H"""
    {{ hidden_inputs_for(form) }}
    """
  end
end
