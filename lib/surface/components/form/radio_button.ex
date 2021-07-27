defmodule Surface.Components.Form.RadioButton do
  @moduledoc """
  Defines a radio button.

  Provides a wrapper for Phoenix.HTML.Form's `radio_button/4` function.

  All options passed via `opts` will be sent to `radio_button/4`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <RadioButton form="user" field="color" opts={autofocus: "autofocus"} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [radio_button: 4]
  import Surface.Components.Utils, only: [events_to_opts: 1]
  import Surface.Components.Form.Utils

  @doc "Indicates whether or not the radio button is the selected item in the group"
  prop checked, :boolean

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:checked, class: get_default_class()])
    event_opts = events_to_opts(assigns)

    opts =
      assigns.opts
      |> Keyword.merge(helper_opts)
      |> Keyword.merge(attr_opts)
      |> Keyword.merge(event_opts)

    assigns = assign(assigns, opts: opts)

    ~F"""
    <InputContext assigns={assigns} :let={form: form, field: field}>
      {radio_button(form, field, assigns[:value], @opts)}
    </InputContext>
    """
  end
end
