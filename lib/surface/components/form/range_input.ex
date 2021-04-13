defmodule Surface.Components.Form.RangeInput do
  @moduledoc """
  An input field that let the user specify a numeric value in a given **range**,
  usually using a slider.

  Provides a wrapper for Phoenix.HTML.Form's `range_input/3` function.

  All options passed via `opts` will be sent to `range_input/3`, `value`, `min`, `max`
  and `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <RangeInput form="volume" field="percent" min="0" max="100" step="5" value="40" opts={{ autofocus: "autofocus" }} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [range_input: 3]
  import Surface.Components.Form.Utils

  @doc "Minimum value for the input"
  prop min, :string

  @doc "Maximum value for the input"
  prop max, :string

  @doc "Sets or returns the value of the step attribute of the slider control"
  prop step, :string

  def render(assigns) do
    helper_opts = props_to_opts(assigns)

    attr_opts =
      props_to_attr_opts(assigns, [:value, :min, :max, :step, class: get_config(:default_class)])

    event_opts = events_to_opts(assigns)

    ~H"""
    <InputContext assigns={{ assigns }} :let={{ form: form, field: field }}>
      {{ range_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_opts) }}
    </InputContext>
    """
  end
end
