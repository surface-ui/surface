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

  @doc "The form identifier"
  property form, :form

  @doc "The field name"
  property field, :string

  @doc "The CSS class for the underlying tag"
  property class, :css_class

  @doc "Options list"
  property opts, :keyword, default: []

  @doc """
  The content for the label
  """
  slot default

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, class: get_config(:default_class))
    children = ~H"<slot>{{ Phoenix.Naming.humanize(field) }}</slot>"

    ~H"""
    {{ label(form, field, props ++ @opts, do: children) }}
    """
  end
end
