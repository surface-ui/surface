defmodule Surface.Components.Form.SearchInput do
  @moduledoc """
  Generates a text input.

  Provides a wrapper for Phoenix.HTML.Form's `search_input/3` function.

  All options passed via `opts` will be sent to `search_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <SearchInput form="song" field="title" opts={{ [autofocus: "autofocus"] }}>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Form, only: [search_input: 3]
  import Surface.Components.Form.Utils

  alias Surface.Components.Form

  @doc "An identifier for the form"
  property form, :form

  @doc "An identifier for the input"
  property field, :string, required: true

  @doc "Value to pre-populated the input"
  property value, :string

  @doc "Class or classes to apply to the input"
  property class, :css_class

  @doc "Keyword list with options to be passed down to `search_input/3`"
  property opts, :keyword, default: []

  @doc "Triggered when the component loses focus"
  property blur, :event

  @doc "Triggered when the component receives focus"
  property focus, :event

  @doc "Triggered when the component receives click"
  property capture_click, :event

  @doc "Triggered when a button on the keyboard is pressed"
  property keydown, :event

  @doc "Triggered when a button on the keyboard is released"
  property keyup, :event

  context get form, from: Form, as: :form_context

  def render(assigns) do
    form = get_form(assigns)
    props = get_non_nil_props(assigns, [:value, :class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{
      search_input(
        form,
        String.to_atom(@field),
        props ++ @opts ++ event_opts
      )
    }}
    """
  end
end
