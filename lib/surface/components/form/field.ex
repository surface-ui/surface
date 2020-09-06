defmodule Surface.Components.Form.Field do
  @moduledoc """
  Defines a form field.

  The `Field` component sets the provided field name into the context so child
  components like input fields and labels can retrieve it and use it as
  the default field.
  """

  use Surface.Component

  @doc "The field name"
  property name, :string, required: true

  @doc "The CSS class for the generated `<div>` element"
  property class, :css_class

  @doc """
  The content for the field
  """
  slot default, required: true

  def render(assigns) do
    ~H"""
    <div class={{ class_value(@class) }}>
      <Context :set={{ :field, @name, scope: __MODULE__ }}>
        <slot/>
      </Context>
    </div>
    """
  end

  defp class_value(class) do
    class || get_config(:default_class) || ""
  end
end
