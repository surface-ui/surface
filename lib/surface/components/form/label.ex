defmodule Surface.Components.Form.Label do
  @moduledoc """
  Defines a label.

  Provides similar capabilities to Phoenix's built-in `label/2`
  function.

  Option `class` can be set directly and will override anything in `opts`.

  All given options are forwarded to the underlying tag. A default value is
  provided for for attribute but can be overriden if you pass a value to the
  for option. Text content would be inferred from field if not specified.
  """

  use Surface.Component

  import Surface.Components.Form.Utils
  alias Surface.Components.Form.Input.InputContext

  @doc "The form identifier"
  prop form, :form

  @doc "The field name"
  prop field, :atom

  @doc "The CSS class for the underlying tag"
  prop class, :css_class

  @doc """
  The text for the generated `<label>` element, if no content (default slot) is provided.
  """
  prop text, :any

  @doc "Options list"
  prop opts, :keyword, default: []

  @doc """
  The text for the label
  """
  slot default

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, class: get_config(:default_class))

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      <label :attrs={{ helper_opts ++ attr_opts ++ input_id(form, field) ++ @opts }}>
        <slot>{{ @text || Phoenix.Naming.humanize(field) }}</slot>
      </label>
    </InputContext>
    """
  end

  defp input_id(form, field) when is_nil(form) or is_nil(field), do: []

  defp input_id(form, field) do
    [for: Phoenix.HTML.Form.input_id(form, field)]
  end
end
