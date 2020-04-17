defmodule Surface.Components.Form.Form do
  use Surface.Component

  import Phoenix.HTML.Form

  alias Surface.Components.Raw

  property for, :any, required: true
  property action, :string, required: true
  property opts, :keyword, default: []

  context set form, :form

  def init_context(assigns) do
    form = form_for(assigns.for, assigns.action, assigns.opts)
    {:ok, form: form}
  end

  def render(assigns) do
    ~H"""
    {{ @form }}
      {{ @inner_content && @inner_content.([]) }}
    <#Raw></form></#Raw>
    """
  end
end
