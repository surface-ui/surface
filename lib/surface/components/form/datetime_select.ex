defmodule Surface.Components.Form.DateTimeSelect do
  @moduledoc """
  Generates select tags for datetime.

  Provides a wrapper for Phoenix.HTML.Form's `datetime_select/3` function.

  All options passed via `opts` will be sent to `datetime_select/3`, `value`
  can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <DateTimeSelect form="user" field="born_at" />

  <Form for={{ :user }}>
    <DateTimeSelect field={{ :born_at }} />
  </Form>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [datetime_select: 3]
  alias Surface.Components.Form.Input.InputContext

  @doc "The form identifier"
  prop form, :form

  @doc "The field name"
  prop field, :string

  @doc "Value to pre-populate the select"
  prop value, :any

  @doc "Options list"
  prop opts, :keyword, default: []

  def render(assigns) do
    props =
      case assigns[:value] do
        nil -> []
        value -> [value: value]
      end

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ datetime_select(form, field, props ++ @opts) }}
    </InputContext>
    """
  end
end
