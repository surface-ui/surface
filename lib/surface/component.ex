defmodule Surface.Component do
  @moduledoc """
  Defines a stateless component.

  ## Example

      defmodule Button do
        use Surface.Component

        prop click, :event

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
  alias Surface.BaseComponent

  defmacro __using__(opts \\ []) do
    slot_name = Keyword.get(opts, :slot)

    if slot_name do
      validate_slot_name!(slot_name, __CALLER__)
    end

    quote do
      @before_compile Surface.Renderer
      use Phoenix.LiveComponent

      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:prop, :slot, :data]
      import Phoenix.HTML

      @before_compile unquote(__MODULE__)

      alias Surface.Constructs.{For, If}
      alias Surface.Components.Context

      @doc "Built-in assign"
      data socket, :struct

      @doc "Built-in assign"
      data flash, :map

      @doc "Built-in assign"
      data inner_block, :fun

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
    [quoted_mount(env), quoted_update(env)]
  end

  defp quoted_update(env) do
    if Module.defines?(env.module, {:update, 2}) do
      quote do
        defoverridable update: 2

        def update(assigns, socket) do
          assigns = unquote(__MODULE__).restore_id(assigns)
          {:ok, socket} = super(assigns, socket)
          {:ok, BaseComponent.restore_private_assigns(socket, assigns)}
        end
      end
    else
      quote do
        def update(assigns, socket) do
          assigns = unquote(__MODULE__).restore_id(assigns)
          {:ok, assign(socket, assigns)}
        end
      end
    end
  end

  defp quoted_mount(env) do
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

  @doc false
  def restore_id(assigns) do
    case Map.pop(assigns, :__id__) do
      {nil, rest} -> rest
      {id, rest} -> Map.put(rest, :id, id)
    end
  end
end
