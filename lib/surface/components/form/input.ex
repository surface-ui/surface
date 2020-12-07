defmodule Surface.Components.Form.Input do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      use Surface.Component

      import unquote(__MODULE__)
      alias Surface.Components.Form.Input.InputContext

      @doc "An identifier for the form"
      prop form, :form

      @doc "An identifier for the input"
      prop field, :atom

      @doc "The id of the corresponding input field"
      prop id, :string

      @doc "The name of the corresponding input field"
      prop name, :string

      @doc "Value to pre-populated the input"
      prop value, :string

      @doc "Class or classes to apply to the input"
      prop class, :css_class

      @doc "Options list"
      prop opts, :keyword, default: []

      @doc "Triggered when the component loses focus"
      prop blur, :event

      @doc "Triggered when the component receives focus"
      prop focus, :event

      @doc "Triggered when the component receives click"
      prop capture_click, :event

      @doc "Triggered when a button on the keyboard is pressed"
      prop keydown, :event

      @doc "Triggered when a button on the keyboard is released"
      prop keyup, :event
    end
  end

  defmacro get_default_class() do
    quote do
      unquote(__MODULE__).get_default_class(__MODULE__)
    end
  end

  def get_default_class(component) do
    config = Surface.get_components_config()
    config[component][:default_class] || config[__MODULE__][:default_class]
  end

  defmodule InputContext do
    use Surface.Component

    @doc "The assigns of the host component"
    prop assigns, :map

    slot default, props: [:form, :field]

    def render(assigns) do
      ~H"""
      <Context
        get={{ Surface.Components.Form, form: form }}
        get={{ Surface.Components.Form.Field, field: field }}>
        <slot :props={{ form: @assigns[:form] || form, field: @assigns[:field] || field }}/>
      </Context>
      """
    end
  end
end
