defmodule Surface.Components.Form.TimeSelect do
  @moduledoc """
  Generates select tags for time.

  Provides a wrapper for Phoenix.HTML.Form's `time_select/3` function.

  All options passed via `opts` will be sent to `time_select/3`,
  `value`, `default`, `hour`, `minute`, `second` and `builder`
  can be set directly and will override anything in `opts`.

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
  import Surface.Components.Form.Utils
  alias Surface.Components.Form.Input.InputContext

  @doc "The form identifier"
  prop form, :form

  @doc "The field name"
  prop field, :string

  @doc "The id prefix for underlying select fields"
  prop id, :string

  @doc "The name prefix for underlying select fields"
  prop name, :string

  @doc "Value to pre-populate the select"
  prop value, :any

  @doc "Default value to use when none was given in 'value' and none is available in the form data"
  prop default, :any

  @doc "Options passed to the underlying 'day' select"
  prop hour, :keyword

  @doc "Options passed to the underlying 'day' select"
  prop minute, :keyword

  @doc "Options passed to the underlying 'day' select"
  prop second, :keyword

  @doc """
  Specify how the select can be build. It must be a function that receives a builder
  that should be invoked with the select name and a set of options.
  """
  prop builder, :fun

  @doc "Options list"
  prop opts, :keyword, default: []

  def render(assigns) do
    helper_opts =
      props_to_opts(assigns, [
        :value,
        :default,
        :hour,
        :minute,
        :second,
        :builder
      ])

    helper_opts =
      helper_opts
      |> parse_css_class_for(:hour)
      |> parse_css_class_for(:minute)
      |> parse_css_class_for(:second)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ time_select(form, field, helper_opts ++ @opts) }}
    </InputContext>
    """
  end
end
