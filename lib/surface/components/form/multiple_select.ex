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
  alias Surface.Components.Form.Input.InputContext

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

  def render(assigns) do
    props = get_non_nil_props(assigns, class: get_config(:default_class))

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ multiple_select(form, field, @options, props ++ @opts) }}
    </InputContext>
    """
  end
end
