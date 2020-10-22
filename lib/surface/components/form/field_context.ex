defmodule Surface.Components.Form.FieldContext do
  @moduledoc """
  Defines a context for a form field but without the `<div>` wrapper in `Field`.

  Like the `Field` component, sets the provided field name into the context
  so child components like input fields and labels can retrieve it and use it as
  the default field.
  """

  use Surface.Component

  alias Surface.Components.Form.Field

  @doc "The field name"
  prop name, :atom, required: true

  @doc """
  The content for the field
  """
  slot default, required: true

  def render(assigns) do
    ~H"""
    <Context put={{ Field, field: @name }}>
      <slot/>
    </Context>
    """
  end
end
