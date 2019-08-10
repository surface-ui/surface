defmodule Surface.Event do

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
      def handle_event(<<"__", path :: binary()>>, value, socket) do
        [comp_id, event, mod_str] = String.split(path, ":")
        mod = Module.concat([mod_str])

        IO.inspect({comp_id, event, mod}, label: "event called")

        mappings = __bindings_mapping__()
        bindings = assings_to_bindings(mappings, comp_id, socket.assigns)
        updated_bindings = mod.handle_event(event, bindings, value)
        updated_assigns = bindings_to_assigns(mappings, comp_id, updated_bindings)

        {:noreply, assign(socket, updated_assigns)}
      end
    end
  end
end
