defmodule Surface.PropertiesTest.Components do
  defmodule MyComponent do
    use Surface.Component

    @doc "The label"
    prop label, :string, required: true

    @doc "The class"
    prop class, :css_class

    @doc "The click event"
    prop click, :event, required: true

    @doc "The cancel event"
    prop cancel, :event

    @doc "The default slot"
    slot default

    @doc "The required header slot"
    slot header, required: true

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@default} />
      </div>
      """
    end
  end

  defmodule MyComponentWithModuledoc do
    use Surface.Component

    @moduledoc """
    My component with @moduledoc
    """

    @doc "The label"
    prop label, :string, required: true

    @doc "The class"
    prop class, :css_class

    @doc "The click event"
    prop click, :event, required: true

    @doc "The cancel event"
    prop cancel, :event

    @doc "The default slot"
    slot default

    @doc "The required header slot"
    slot header, required: true

    def render(assigns) do
      ~F"""
      <div>
        <#slot {@default} />
      </div>
      """
    end
  end

  defmodule MyComponentWithModuledocFalse do
    use Surface.Component

    @moduledoc false

    @doc "The label"
    prop label, :string, required: true

    @doc "The class"
    prop class, :css_class

    def render(assigns) do
      ~F"""
      <div />
      """
    end
  end

  defmodule MyComponentWithDocButPropSlotAndEvent do
    use Surface.Component

    @moduledoc """
    My Component with doc but props, slots and events
    """

    def render(assigns) do
      ~F"""
      <div />
      """
    end
  end
end
