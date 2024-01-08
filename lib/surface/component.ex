defmodule Surface.Component do
  @moduledoc """
  Defines a stateless component.

  ## Example

      defmodule Button do
        use Surface.Component

        prop click, :event

        def render(assigns) do
          ~F"\""
          <button class="button" :on-click={@click}>
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

      use Phoenix.Component, unquote(Keyword.drop(opts, [:slot]))
      import Phoenix.Component, except: [slot: 1, slot: 2]

      @behaviour unquote(__MODULE__)

      use Surface.BaseComponent, type: unquote(__MODULE__)

      use Surface.API, include: [:prop, :slot, :data]
      import Phoenix.HTML

      @before_compile {Surface.BaseComponent, :__before_compile_init_slots__}
      @before_compile {unquote(__MODULE__), :__before_compile_handle_from_context__}

      alias Surface.Components.{Context, Raw}
      alias Surface.Components.Dynamic.Component

      @doc "Built-in assign"
      data inner_block, :fun

      defmacro __using__(opts) do
        alias_opts = Keyword.take(opts, [:as])

        quote do
          alias unquote(__MODULE__), unquote(alias_opts)
          Module.put_attribute(__MODULE__, :__compile_time_deps__, unquote(__MODULE__))
        end
      end

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

  defmacro __before_compile_handle_from_context__(env) do
    props_specs = env.module |> Surface.API.get_props() |> Enum.reverse()
    data_specs = env.module |> Surface.API.get_data() |> Enum.reverse()

    quoted_props_assigns =
      for %{name: name, opts: opts} <- props_specs, key = opts[:from_context] do
        quote do
          var!(assigns) =
            Surface.Components.Context.maybe_copy_assign(var!(assigns), unquote(key), as: unquote(name))
        end
      end

    quoted_data_assigns =
      for %{name: name, opts: opts} <- data_specs, key = opts[:from_context] do
        quote do
          var!(assigns) = Surface.Components.Context.copy_assign(var!(assigns), unquote(key), as: unquote(name))
        end
      end

    quoted_caller_scope_id =
      quote do
        var!(assigns) = Phoenix.Component.assign_new(var!(assigns), :__caller_scope_id__, fn -> nil end)
      end

    quoted_assigns = {:__block__, [], [quoted_caller_scope_id] ++ quoted_data_assigns ++ quoted_props_assigns}

    if Module.defines?(env.module, {:render, 1}) do
      quote do
        defoverridable render: 1

        def render(var!(assigns)) do
          unquote(quoted_assigns)

          super(var!(assigns))
        end
      end
    end
  end

  defp quoted_render(env) do
    if !Module.defines?(env.module, {:__slot_name__, 0}) ||
         Module.defines?(env.module, {:render, 1}) do
      quote do
        @doc false
        def __renderless__? do
          false
        end
      end
    else
      quote do
        @doc false
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
