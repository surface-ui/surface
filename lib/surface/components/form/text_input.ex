defmodule Surface.Components.Form.TextInput do
  use Surface.Component

  property field, :string, required: true
  property value, :string, default: ""
  property class, :css_class

  def render(assigns) do
    ~H"""
    <input
      type="text"
      class={{ @class }}
      id={{ @field }}
      value={{ @value }}
    />
    """
  end
end
