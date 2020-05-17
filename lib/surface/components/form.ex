defmodule Surface.Components.Form do
  @moduledoc """
  Generates a form.

  Provides a wrapper for `Phoenix.HTML.Form.form_for/3`. Additionally,
  adds the form instance that is returned by `form_for/3` into the context,
  making it available to any child input.

  All options passed via `opts` will be sent to `form_for/3`, `for`
  and `action` can be set directly and will override anything in `opts`.

  """

  use Surface.Component

  import Phoenix.HTML.Form
  alias Surface.Components.Raw

  @doc "Atom or changeset to inform the form data"
  property for, :any, required: true

  @doc "URL to where the form is submitted"
  property action, :string, required: true

  @doc "Keyword list with options to be passed down to `form_for/3`"
  property opts, :keyword, default: []

  @doc "Triggered when the form is changed"
  property change, :event

  @doc "Triggered when the form is submitted"
  property submit, :event

  @doc "The content of the `<form>`"
  slot default

  @doc "The form instance initialized by the Form component"
  context set form, :form

  def init_context(assigns) do
    opts =
      assigns.opts ++
        event_to_opts(assigns.change, :phx_change) ++
        event_to_opts(assigns.submit, :phx_submit)

    form = form_for(assigns.for, assigns.action, opts)
    {:ok, form: form}
  end

  def render(assigns) do
    ~H"""
    {{ @form }}
      <slot/>
    <#Raw></form></#Raw>
    """
  end
end
