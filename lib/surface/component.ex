defmodule Surface.Component do
  alias Surface.Translator

  defmacro __using__(_) do
    quote do
      use Surface.BaseComponent
      use Surface.Binding
      use Surface.EventValidator

      require Surface.LiveEngine

      import unquote(__MODULE__)
      @behaviour unquote(__MODULE__)

      defdelegate render_code(mod_str, attributes, children_iolist, mod, caller),
        to: Surface.ComponentRenderer

      defoverridable render_code: 5
    end
  end

  @callback begin_context(props :: map()) :: map()
  @callback end_context(props :: map()) :: map()
  @callback render(assigns :: map()) :: any

  @optional_callbacks begin_context: 1, end_context: 1

  defmacro sigil_H({:<<>>, _, [string]}, _) do
    line_offset = __CALLER__.line + 1
    string
    |> Translator.translate(line_offset, __CALLER__)
    |> EEx.compile_string(engine: Surface.LiveEngine, line: line_offset)
  end

  defmacro event(event_name) do
    quote do
      "__" <> Map.get(var!(assigns), :__component_id) <> ":" <> to_string(unquote(event_name))
    end
  end
end
