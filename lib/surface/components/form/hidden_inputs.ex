defmodule Surface.Components.Form.HiddenInputs do
  @moduledoc """
  A wrapper for `Phoenix.HTML.Form.html.hidden_inputs_for/1`.

  Generates hidden inputs for the given form.
  """

  use Surface.Component

  import Phoenix.HTML.Form

  @doc """
  The form.

  It should either be a `Phoenix.HTML.Form` emitted by `form_for`, `inputs_for` or an atom.
  """
  prop for, :form, from_context: {Surface.Components.Form, :form}

  def render(assigns) do
    ~F[{hidden_inputs_for(@for)}]
  end
end
