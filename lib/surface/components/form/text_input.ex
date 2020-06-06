defmodule Surface.Components.Form.TextInput do
  @moduledoc """
  An input field that let the user enter a **single-line text**.

  Provides a wrapper for Phoenix.HTML.Form's `text_input/3` function.

  All options passed via `opts` will be sent to `text_input/3`, `value` and
  `class` can be set directly and will override anything in `opts`.


  ## Examples

  ```
  <TextInput form="user" field="name" opts={{ autofocus: "autofocus" }} />
  ```
  """

  use Surface.Components.Form.Input

  import Phoenix.HTML.Form, only: [text_input: 3]
  import Surface.Components.Form.Utils
  alias Surface.Components.Form.Input

  context get form, from: Form, as: :form_context
  context get field, from: Field, as: :field_context

  @default_class get_config(:default_class) || get_config(Input, :default_class)

  def render(assigns) do
    form = get_form(assigns)
    field = get_field(assigns)
    props = get_non_nil_props(assigns, [:value, class: @default_class])
    event_opts = get_events_to_opts(assigns)

    ~H"""
    {{ text_input(form, field, props ++ @opts ++ event_opts) }}
    """
  end
end
