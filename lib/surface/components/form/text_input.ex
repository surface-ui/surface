defmodule Surface.Components.Form.TextInput do
  use Surface.Component

  import Phoenix.HTML.Form

  property form, :string, required: true
  property field, :string, required: true
  property value, :string, default: ""
  property class, :css_class
  property opts, :keyword, default: []

  def render(assigns) do
    ~H"""
    {{
      text_input(
        String.to_atom(@form),
        @field,
        [
          value: @value,
          class: @class,
        ] ++ @opts
      )
    }}
    """
  end
end
