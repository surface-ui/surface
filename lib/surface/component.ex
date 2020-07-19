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
            <slot/>
          </button>
          "\""
        end
      end

  > **Note**: Stateless components cannot handle Phoenix LiveView events.
  If you need to handle them, please use a `Surface.LiveComponent` instead.
  """

  alias Surface.IOHelper

  defmacro __using__(opts \\ []) do
    slot_name = Keyword.get(opts, :slot)

    translator =
      if slot_name do
        validate_slot_name!(slot_name, __CALLER__)
        Surface.Translator.SlotableTranslator
      else
        Surface.Translator.ComponentTranslator
      end

    quote do
      use Phoenix.LiveComponent
      use Surface.BaseComponent, translator: unquote(translator)
      use Surface.API, include: [:property, :slot, :context]
      import Phoenix.HTML

      @behaviour unquote(__MODULE__)
      @before_compile Surface.Renderer
      @before_compile Surface.ContentHandler

      if unquote(translator) == Surface.Translator.SlotableTranslator do
        def render(var!(assigns)) do
          ~H()
        end

        def __slot_name__ do
          unquote(slot_name && String.to_atom(slot_name))
        end

        defoverridable render: 1
      end
    end
  end

  defp validate_slot_name!(name, caller) do
    if !is_binary(name) do
      message = "invalid value for option :slot. Expected a string, got: #{inspect(name)}"
      IOHelper.compile_error(message, caller.file, caller.line)
    end
  end

  @doc """
  This optional callback is invoked in order to set up a
  context that can be retrieved for any descendent component.
  """
  @callback init_context(props :: map()) :: {:ok, keyword} | {:error, String.t()}

  @optional_callbacks init_context: 1
end
