defmodule Surface.Components.Form.TimeSelect do
  @moduledoc """
  Generates select tags for time.

  Provides a wrapper for Phoenix.HTML.Form's `time_select/3` function.

  All options passed via `opts` will be sent to `time_select/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TimeSelect form="alarm" field="time" />

  <Form for={{ :alarm }}>
    <TimeSelect field={{ :time }} />
  </Form>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [time_select: 3]
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
      {{ time_select(form, field, props ++ @opts) }}
    </InputContext>
    """
  end
end
