defmodule Surface.Components.Form.Utils do
  @moduledoc false

  def get_form(%{form: form}) when is_binary(form), do: String.to_atom(form)
  def get_form(%{form: nil, form_context: form_context}), do: form_context

  def get_non_nil_props(assigns, props) do
    for prop <- props, assigns[prop] do
      {prop, assigns[prop]}
    end
  end
end
