defmodule Surface.Components.Form.HiddenInput do
  @moduledoc """
  A **hidden** input field.

  Provides a wrapper for Phoenix.HTML.Form's `hidden_input/3` function.

  All options passed via `opts` will be sent to `hidden_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <HiddenInput form="user" field="token" opts={autofocus: "autofocus"} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [hidden_input: 3]
  import Surface.Components.Utils, only: [events_to_opts: 1]
  import Surface.Components.Form.Utils

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, :class])
    event_attrs = events_to_opts(assigns)

    ~F"""
    <InputContext assigns={assigns} :let={form: form, field: field}>
      {hidden_input(form, field, helper_opts ++ attr_opts ++ @opts ++ event_attrs)}
    </InputContext>
    """
  end
end
