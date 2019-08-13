defmodule Surface.EventHandler do

  alias Surface.Binding

  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def handle_event(<<"__", comp_event :: binary()>>, value, socket) do
        updated_assigns = unquote(__MODULE__).handle_component_event(__MODULE__, comp_event, value, socket)
        {:noreply, assign(socket, updated_assigns)}
      end
    end
  end

  def handle_component_event(module, comp_event, value, socket) do
    [comp, event] = String.split(comp_event, ":")
    target_module =
      comp
      |> String.split("_")
      |> Enum.reduce(module, fn id, mod -> mod.__children__()[id] end)

    bindings = module.__bindings__()
    bindings_map = Binding.assings_to_bindings_map(bindings, comp, socket.assigns)
    updated_bindings_map = target_module.handle_event(event, bindings_map, value)
    Binding.bindings_map_to_assigns(bindings, comp, updated_bindings_map)
  end
end
