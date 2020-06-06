defmodule Surface.Components.Form.Field do
  @moduledoc """
  Generates a form field.

  The `Field` component sets the provided field name into the context so child
  components like input fields and labels can retrieve it and use it as
  the default field.
  """

  use Surface.Component

  @doc "The field name"
  property field, :string, required: true

  @doc "The CSS class for the generated `<div>` element"
  property class, :css_class, default: ""

  @doc "The field name specified by the <Field/> component"
  context set field, :atom, scope: :only_children

  @doc """
  The content for the field
  """
  slot default, required: true

  def init_context(props) do
    {:ok, field: props.field}
  end

  def render(assigns) do
    ~H"""
    <div class={{ @class }}>
      <slot/>
    </div>
    """
  end
end
