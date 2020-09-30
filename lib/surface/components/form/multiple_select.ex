defmodule Surface.Components.Form.MultipleSelect do
  @moduledoc """
  Defines a select.

  Provides a wrapper for Phoenix.HTML.Form's `multiple_select/4` function.

  All options passed via `opts` will be sent to `multiple_select/4`, `class` can
  be set directly and will override anything in `opts`.
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [multiple_select: 4]
  import Surface.Components.Form.Utils

  @doc "The form identifier"
  property form, :form

  @doc "The field name"
  property field, :string

  @doc "The CSS class for the underlying tag"
  property class, :css_class

  @doc "The options in the select"
  property options, :any, default: []

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

    ~H"""
    {{ multiple_select(form, field, @options, props ++ @opts) }}
    """
  end
end
