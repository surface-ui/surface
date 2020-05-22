defmodule Surface.PropertiesTest.Components do
  defmodule MyComponent do
    use Surface.Component

    @doc "The label"
    property label, :string, required: true, default: ""

    @doc "The class"
    property class, :css_class

    def render(assigns) do
      ~H"""
      <div />
      """
    end
  end

  defmodule MyComponentWithModuledoc do
    use Surface.Component

    @moduledoc """
    My component with @moduledoc
    """

    @doc "The label"
    property label, :string, required: true, default: ""

    @doc "The class"
    property class, :css_class

    def render(assigns) do
      ~H"""
      <div />
      """
    end
  end

  defmodule MyComponentWithModuledocFalse do
    use Surface.Component

    @moduledoc false

    @doc "The label"
    property label, :string, required: true, default: ""

    @doc "The class"
    property class, :css_class

    def render(assigns) do
      ~H"""
      <div />
      """
    end
  end
end
