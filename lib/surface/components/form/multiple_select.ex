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
  prop form, :form

  @doc "The field name"
  prop field, :string

  @doc "The id of the corresponding select field"
  prop id, :string

  @doc "The name of the corresponding select field"
  prop name, :string

  @doc "The CSS class for the underlying tag"
  prop class, :css_class

  @doc "The options in the select"
  prop options, :any, default: []

  @doc "The default selected option"
  prop selected, :any

  @doc "Options list"
  prop opts, :keyword, default: []

  def render(assigns) do
    helper_opts = props_to_opts(assigns, [:selected])
    attr_opts = props_to_attr_opts(assigns, class: get_config(:default_class))

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ multiple_select(form, field, @options, helper_opts ++ attr_opts ++ @opts) }}
    </InputContext>
    """
  end
end
