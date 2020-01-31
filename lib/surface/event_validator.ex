defmodule Surface.EventValidator do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)

      Module.register_attribute __MODULE__, :event_handlers, accumulate: true, persist: false
      Module.register_attribute __MODULE__, :event_references, accumulate: true, persist: false

      @before_compile unquote(__MODULE__)
      @after_compile unquote(__MODULE__)
      @on_definition {unquote(__MODULE__), :__on_definition__}
    end
  end

  def __on_definition__(env, :def, :handle_event, [pattern | _args], guards, _body) do
    Module.put_attribute(env.module, :event_handlers, {pattern, guards})
  end

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  defmacro __before_compile__(env) do
    event_handlers = Module.get_attribute(env.module, :event_handlers) |> Enum.uniq()
    {defs, has_catch_all?} =
      Enum.reduce(event_handlers, {[], false}, fn {pattern, guards}, {defs, has_catch_all?} ->
        def_ast = quoted_has_event_handler(pattern, guards)
        has_catch_all? =
          has_catch_all? || (match?({var, [_|_], _} when is_atom(var), pattern) && guards == [])
        {[def_ast | defs], has_catch_all?}
      end)

    has_handler_catch_all_def =
      if has_catch_all? do
        []
      else
        [quoted_has_event_handler_catch_all()]
      end

    defs ++ has_handler_catch_all_def
  end

  def __after_compile__(env, _) do
    event_references = Module.get_attribute(env.module, :event_references)
    for {event, line} <- event_references,
        !env.module.__has_event_handler__?(event) do
      message = "Unhandled event \"#{event}\" (module #{inspect(env.module)} does not implement a matching handle_message/2)"
      Surface.Translator.IO.warn(message, env, fn _ -> line end)
    end
  end

  defp quoted_has_event_handler_catch_all() do
    quote do
      def __has_event_handler__?(_) do
        false
      end
    end
  end

  defp quoted_has_event_handler(pattern, []) do
    body = quoted_has_event_handler_body(pattern)
    quote do
      def __has_event_handler__?(unquote(pattern)) do
        unquote(body)
      end
    end
  end

  defp quoted_has_event_handler(pattern, guards) do
    body = quoted_has_event_handler_body(pattern)
    quote do
      def __has_event_handler__?(unquote(pattern)) when unquote_splicing(guards) do
        unquote(body)
      end
    end
  end

  defp quoted_has_event_handler_body(pattern) do
    vars =
      pattern
      |> extract_vars()
      |> Enum.map(fn v -> {v, [line: 1], nil} end)

    quote do
      _ = unquote(vars) # Avoids "variable X is unused" warnings
      true
    end
  end

  defp extract_vars(ast) do
    {_ast, acc} = Macro.prewalk(ast, [], &extract_var/2)
    acc |> Enum.reverse()
  end

  defp extract_var(_ast = {:"::", [line: _], [var, _]}, acc) do
    {[var], acc}
  end

  defp extract_var(ast = {var_name, [line: _], nil}, acc) do
    if to_string(var_name) |> String.starts_with?("_") do
      {ast, acc}
    else
      {ast, [var_name | acc]}
    end
  end

  defp extract_var(ast, acc) do
    {ast, acc}
  end
end
