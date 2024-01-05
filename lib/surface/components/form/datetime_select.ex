defmodule Surface.Components.Form.DateTimeSelect do
  @moduledoc """
  Generates select tags for datetime.

  Provides a wrapper for PhoenixHTMLHelpers.Form's `datetime_select/3` function.

  All options passed via `opts` will be sent to `datetime_select/3`,
  `value`, `default`, `year`, `month`, `day`, `hour`, `minute`, `second` and `builder`
  can be set directly and will override anything in `opts`.

  ## Examples

  ```
  <DateTimeSelect form="user" field="born_at" />

  <Form for={:user}>
    <DateTimeSelect field={:born_at} />
  </Form>
  ```
  """

  use Surface.Component

  import PhoenixHTMLHelpers.Form, only: [datetime_select: 3]
  import Surface.Components.Form.Utils

  @doc "The form identifier"
  prop form, :form, from_context: {Surface.Components.Form, :form}

  @doc "The field name"
  prop field, :any, from_context: {Surface.Components.Form.Field, :field}

  @doc "The id prefix for underlying select fields"
  prop id, :string

  @doc "The name prefix for underlying select fields"
  prop name, :string

  @doc "Value to pre-populate the select"
  prop value, :any

  @doc "Default value to use when none was given in 'value' and none is available in the form data"
  prop default, :any

  @doc "Options passed to the underlying 'year' select"
  prop year, :keyword

  @doc "Options passed to the underlying 'month' select"
  prop month, :keyword

  @doc "Options passed to the underlying 'day' select"
  prop day, :keyword

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
      assigns
      |> props_to_opts([:value, :default, :year, :month, :day, :hour, :minute, :second, :builder])
      |> parse_css_class_for(:year)
      |> parse_css_class_for(:month)
      |> parse_css_class_for(:day)
      |> parse_css_class_for(:hour)
      |> parse_css_class_for(:minute)
      |> parse_css_class_for(:second)

    opts =
      assigns.opts
      |> Keyword.merge(helper_opts)

    assigns = assign(assigns, opts: opts)

    ~F[{datetime_select(@form, @field, @opts)}]
  end
end
