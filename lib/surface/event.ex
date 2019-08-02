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

    has_handler_defs ++ [has_handler_catch_all_def]
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

end
