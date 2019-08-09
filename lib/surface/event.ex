defmodule Surface.Event do

  defmacro __using__(_) do
    quote do
      import Kernel, except: [def: 2]
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :event_handlers, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :event_references, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :bindings_mapping, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :children, accumulate: true, persist: false
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

    children = Module.get_attribute(env.module, :children) |> Enum.uniq()

    bindings_mapping =
      Module.get_attribute(env.module, :bindings_mapping)
      |> Enum.uniq()
      |> Map.new

    bindings_mapping_def =
      quote do
        def __bindings_mapping__() do
          unquote(Macro.escape(bindings_mapping))
        end
      end

    has_handler_defs ++ [has_handler_catch_all_def, bindings_mapping_def, quoted_handle_event_fallback()]
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
      def handle_event(<<"__", comp :: binary-size(11), ":">> <> rest, value, socket) do
        [event, mod_str] = String.split(rest, ":")
        mod = Module.concat([mod_str])

        # TODO: Optimize

        bindings =
          for {{^comp, binding}, assign} <- __bindings_mapping__(), into: %{} do
            {binding, socket.assigns[assign]}
          end

        new_assigns = mod.handle_event(event, bindings, value)

        new_assigns =
          for {{^comp, binding}, assign} <- __bindings_mapping__(), into: [] do
            {assign, new_assigns[binding]}
          end

        {:noreply, assign(socket, new_assigns)}
      end
    end
  end
end
