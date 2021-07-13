defmodule Surface.Component do
  @moduledoc """
  Defines a stateless component.

  ## Example

      defmodule Button do
        use Surface.Component

        prop click, :event

        def render(assigns) do
          ~F"\""
          <button class="button" phx-click={{ @click }}>
            <#slot/>
          </button>
          "\""
        end
      end

  > **Note**: Stateless components cannot handle Phoenix LiveView events.
  If you need to handle them, please use a `Surface.LiveComponent` instead.
  """

  alias Surface.IOHelper

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  defmacro __using__(opts \\ []) do
    slot_name = Keyword.get(opts, :slot)

    if slot_name do
      validate_slot_name!(slot_name, __CALLER__)
    end

    slot_name = slot_name && String.to_atom(slot_name)

    quote do
      @before_compile Surface.Renderer
      @before_compile unquote(__MODULE__)

      use Phoenix.Component

      @behaviour unquote(__MODULE__)

      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:prop, :slot, :data]
      import Phoenix.HTML

      alias Surface.Components.{Context, Raw}

      @doc "Built-in assign"
      data socket, :struct

      @doc "Built-in assign"
      data inner_block, :fun

      if unquote(slot_name) != nil do
        Module.put_attribute(__MODULE__, :__slot_name__, unquote(slot_name))

        def __slot_name__ do
          unquote(slot_name)
        end
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
    quoted_render(env)
  end

  defp quoted_render(env) do
    if !Module.defines?(env.module, {:__slot_name__, 0}) ||
         Module.defines?(env.module, {:render, 1}) do
      quote do
        def __renderless__? do
          false
        end
      end
    else
      quote do
        def __renderless__? do
          true
        end

        def render(var!(assigns)) do
          ~F()
        end
      end
    end
  end
end
