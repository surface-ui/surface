defmodule Surface.Components.Form.Label do
  @moduledoc """
  Defines a label.

  Provides a wrapper for Phoenix.HTML.Form's `label/3` function.

  All options passed via `opts` will be sent to `label/3`, `class` can
  be set directly and will override anything in `opts`.
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [label: 4]
  import Surface.Components.Form.Utils
  alias Surface.Components.Form.Input.InputContext

  @doc "The form identifier"
  property form, :form

  @doc "The field name"
  property field, :atom

  @doc "The CSS class for the underlying tag"
  property class, :css_class

  @doc "Options list"
  property opts, :keyword, default: []

  @doc """
  The text for the label
  """
  slot default

  def render(assigns) do
    props = get_non_nil_props(assigns, class: get_config(:default_class))

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ label(form, field, props ++ @opts, do: children(assigns, field)) }}
    </InputContext>
    """
  end

  def children(assigns, field) do
    ~H"<slot>{{ Phoenix.Naming.humanize(field) }}</slot>"
  end
end
