defmodule Surface.Components.Form.TelephoneInput do
  @moduledoc """
  An input field that let the user enter a **telephone number**.

  Provides a wrapper for PhoenixHTMLHelpers.Form's `telephone_input/3` function.

  All options passed via `opts` will be sent to `telephone_input/3`, `value`,
  `pattern` and `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TelephoneInput form="user" field="phone" opts={autofocus: "autofocus"} />
  ```
  """

  use Surface.Components.Form.Input

  import PhoenixHTMLHelpers.Form, only: [telephone_input: 3]
  import Surface.Components.Utils, only: [events_to_opts: 1]
  import Surface.Components.Form.Utils

  @doc "A regular expression to validate the entered value"
  prop pattern, :string

  def render(assigns) do
    helper_opts = props_to_opts(assigns)
    attr_opts = props_to_attr_opts(assigns, [:value, :pattern, class: get_default_class()])
    event_opts = events_to_opts(assigns)

    opts =
      assigns.opts
      |> Keyword.merge(helper_opts)
      |> Keyword.merge(attr_opts)
      |> Keyword.merge(event_opts)

    assigns = assign(assigns, opts: opts)

    ~F[{telephone_input(@form, @field,  @opts)}]
  end
end
