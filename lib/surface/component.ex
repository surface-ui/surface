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

    if slot_name do
      validate_slot_name!(slot_name, __CALLER__)
    end

    quote do
      @before_compile Surface.Renderer
      use Phoenix.LiveComponent

      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:property, :slot]
      import Phoenix.HTML

      @before_compile unquote(__MODULE__)
      require Surface.ContentHandler
      @before_compile Surface.ContentHandler

      alias Surface.Components.Context

      if unquote(slot_name) != nil do
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

  defmacro __before_compile__(env) do
    if Module.defines?(env.module, {:mount, 1}) do
      quote do
        defoverridable mount: 1

        def mount(socket) do
          super(Surface.init(socket))
        end
      end
    else
      quote do
        def mount(socket) do
          {:ok, Surface.init(socket)}
        end
      end
    end
  end
end
