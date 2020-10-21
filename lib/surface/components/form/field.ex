defmodule Surface.Components.Form.Field do
  @moduledoc """
  Defines a form field.

  The `Field` component sets the provided field name into the context so child
  components like input fields and labels can retrieve it and use it as
  the default field.
  """

  use Surface.Component

  @doc "The field name"
  prop name, :atom, required: true

  @doc """
  The content for the field
  """
  slot default, required: true

  def render(assigns) do
    ~H"""
    <Context put={{ __MODULE__, field: @name }}>
      <slot/>
    </Context>
    """
  end
end
