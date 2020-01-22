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
      use Surface.BaseComponent
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)
      @before_compile Surface.ContentHandler

      def translator do
        Surface.Translator.ComponentTranslator
      end
    end
  end

  @doc """
  This optional callback is invoked in order to set up a
  context that can be retrieved for any descendent component.
  """
  @callback begin_context(props :: map()) :: map()

  @doc """
  This optional callback is invoked in order to clean up a
  context previously created in the `c:begin_context/1`.
  """
  @callback end_context(props :: map()) :: map()

  @optional_callbacks begin_context: 1, end_context: 1
end
