defmodule Surface.Component do
  @moduledoc """
  Defines a stateless component.

  ## Example

      defmodule Button do
        use Surface.Component

        property click, :event

        def render(assigns) do
          ~H"\""
          <button class="button" phx-click={{ @click }}>
            {{ @inner_content.() }}
          </button>
          "\""
        end
      end

  > **Note**: Stateless components cannot handle Phoenix LiveView events.
  If you need to handle them, please use a `Surface.LiveComponent` instead.
  """

  defmacro __using__(_) do
    quote do
      use Phoenix.LiveComponent
      use Surface.BaseComponent, translator: Surface.Translator.ComponentTranslator
      use Surface.API, include: [:property, :context]
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)
      @before_compile Surface.ContentHandler
    end
  end

  @doc """
  This optional callback is invoked in order to set up a
  context that can be retrieved for any descendent component.
  """
  @callback init_context(props :: map()) :: map()

  @optional_callbacks init_context: 1
end
