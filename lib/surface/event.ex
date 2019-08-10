defmodule Surface.Event do

  alias Surface.Binding

  defmacro __using__(_) do
    quote do
      import Kernel, except: [def: 2]
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :event_handlers, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :event_references, accumulate: true, persist: false
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    event_handlers = Module.get_attribute(env.module, :event_handlers) |> Enum.uniq()
    has_handler_defs =
      for pattern <- event_handlers do
        quote do
          def __has_event_handler?(unquote(pattern)) do
            _ = unquote(pattern) # Avoid "variable X is unused" warnings
            true
          end
        end
      end

    has_handler_catch_all_def =
      quote do
        def __has_event_handler?(_) do
          false
        end
      end

    has_handler_defs ++ [has_handler_catch_all_def, quoted_handle_event_fallback()]
  end

  defmacro def(fun_def, opts) do
    quote do
      if pattern = unquote(Macro.escape(extract_event_pattern(fun_def))) do
        Module.put_attribute(__MODULE__, :event_handlers, pattern)
      end
      Kernel.def(unquote(fun_def), unquote(opts))
    end
  end

  defp extract_event_pattern(ast) do
    case ast do
      {:handle_event, [line: _line], [pattern|_]} ->
        pattern
      {:when, _, [{:handle_event, [line: _line], [pattern|_]}, _]} ->
        pattern
      _ ->
        nil
    end
  end

  defp quoted_handle_event_fallback do
    quote do
      def handle_event(<<"__", comp_event :: binary()>>, value, socket) do
        updated_assigns = handle_component_event(__MODULE__, comp_event, value, socket)
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

    mappings = module.__bindings_mapping__()
    bindings = Binding.assings_to_bindings(mappings, comp, socket.assigns)
    updated_bindings = target_module.handle_event(event, bindings, value)
    Binding.bindings_to_assigns(mappings, comp, updated_bindings)
  end
end
