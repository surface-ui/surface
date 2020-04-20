defmodule Surface.Components.Form do
  use Surface.Component

  import Phoenix.HTML.Form

  alias Surface.Components.Raw

  @doc "Atom or changeset to inform the form data"
  property for, :any, required: true

  @doc "URL to where the form is submitted"
  property action, :string, required: true

  @doc "Keyword list with options to be passed down to `form_for/3`"
  property opts, :keyword, default: []

  @doc "The content of the `<form>`"
  slot default

  @doc "The form instance initialized by the Form component"
  context set form, :form

  def init_context(assigns) do
    form = form_for(assigns.for, assigns.action, assigns.opts)
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
