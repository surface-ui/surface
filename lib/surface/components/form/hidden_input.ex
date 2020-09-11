defmodule Surface.Components.Form.HiddenInput do
  @moduledoc """
  A **hidden** input field.

  Provides a wrapper for Phoenix.HTML.Form's `hidden_input/3` function.

  All options passed via `opts` will be sent to `hidden_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <HiddenInput form="user" field="token" opts={{ autofocus: "autofocus" }}>
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [hidden_input: 3]
  import Surface.Components.Form.Utils

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, [:value, :class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{ hidden_input(form, field, props ++ @opts ++ event_opts) }}
    """
  end
end
