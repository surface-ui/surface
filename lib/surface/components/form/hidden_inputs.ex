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
    ~F"""
    {#for {name, value_or_values} <- @for.hidden,
        name = name_for_value_or_values(@for, name, value_or_values),
        value <- List.wrap(value_or_values)}
      <input type="hidden" name={name} value={value}>
    {/for}
    """
  end

  defp name_for_value_or_values(form, field, values) when is_list(values) do
    input_name(form, field) <> "[]"
  end

  defp name_for_value_or_values(form, field, _value) do
    input_name(form, field)
  end
end
