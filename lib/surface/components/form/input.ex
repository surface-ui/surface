defmodule Surface.Components.Form.Input do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use Surface.Component

      alias Surface.Components.Form
      alias Surface.Components.Form.Field

      @doc "An identifier for the form"
      property form, :form

      @doc "An identifier for the input"
      property field, :string

      @doc "Value to pre-populated the input"
      property value, :string

      @doc "Class or classes to apply to the input"
      property class, :css_class

      @doc "Options list"
      property opts, :keyword, default: []

      @doc "Triggered when the component loses focus"
      property blur, :event

      @doc "Triggered when the component receives focus"
      property focus, :event

      @doc "Triggered when the component receives click"
      property capture_click, :event

      @doc "Triggered when a button on the keyboard is pressed"
      property keydown, :event

      @doc "Triggered when a button on the keyboard is released"
      property keyup, :event

      @default_class get_config(:default_class) || get_config(unquote(__MODULE__), :default_class)
    end
  end
end
