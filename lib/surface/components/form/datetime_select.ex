defmodule Surface.Components.Form.DateTimeSelect do
  @moduledoc """
  Generates select tags for datetime.

  Provides a wrapper for Phoenix.HTML.Form's `datetime_select/3` function.

  All options passed via `opts` will be sent to `datetime_select/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <DateTimeSelect form="user" field="born_at" />

  <Form for={{ :user }}>
    <FileInput field={{ :born_at }} />
  </Form>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [datetime_select: 3]
  import Surface.Components.Form.Utils
  alias Surface.Components.Form.Input.InputContext

  @doc "The form identifier"
  prop form, :form

  @doc "The field name"
  prop field, :string

  @doc "Value to pre-populated the select"
  prop value, :any

  @doc "Options list"
  prop opts, :keyword, default: []

  def render(assigns) do
    props = get_non_nil_props(assigns, [:value])

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ datetime_select(form, field, props ++ @opts) }}
    </InputContext>
    """
  end
end
