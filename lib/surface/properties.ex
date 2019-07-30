defmodule Surface.Properties do

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :properties, accumulate: true)
    end
  end

  defmacro property(name, type, opts \\ []) do
    property_ast(name, type, opts)
  end

  defp property_ast(name, type, opts) do
    default = Keyword.get(opts, :default)
    required = Keyword.get(opts, :required, false)

    quote do
      doc = Module.get_attribute(__MODULE__, :doc)
      Module.delete_attribute(__MODULE__, :doc)

      @properties %{
        name: unquote(name),
        type: unquote(type),
        default: unquote(default),
        required: unquote(required),
        doc: doc
      }
    end
  end

  defmacro __before_compile__(env) do
    props = Module.get_attribute(env.module, :properties)
    props_names = Enum.map(props, fn prop -> prop.name end)
    props_by_name = for p <- props, into: %{}, do: {p.name, p}
    # IO.inspect(props_by_name, label: "PROP")
    quote do
      def __props() do
        unquote(Macro.escape(props))
      end

      def __validate_prop__(prop) do
        prop in unquote(props_names)
      end

      def __get_prop__(name) do
        Map.get(unquote(Macro.escape(props_by_name)), name)
      end
    end
  end

  def render_props(props, mod, mod_str, caller) do
    if function_exported?(mod, :__props, 0) do
      props =
        for {key, value, line} <- props do
          key_atom = String.to_atom(key)
          if mod.__props() != [] && !mod.__validate_prop__(key_atom) do
            warn("Invalid property \"#{key}\" for component <#{mod_str}>", caller, line)
          end
          if mod.__get_prop__(key_atom)[:type] == :event do
            Module.put_attribute(caller.module, :event_references, {value, caller.line + line})
          end
          render_prop_value(key, value)
        end ++ ["context: context"]

      ["%{", Enum.join(props, ", "), "}"]
    else
      "%{}"
    end
  end

  defp render_prop_value(key, value) do
    case value do
      {:attribute_expr, value} ->
        expr = value |> IO.iodata_to_binary() |> String.trim()
        [key, ": ", "(", expr, ")"]
      _ ->
        [key, ": ", ~S("), value, ~S(")]
    end
  end

  # TODO: centralize
  def warn(message, caller, template_line) do
    stacktrace =
      Macro.Env.stacktrace(caller)
      |> (fn([{a, b, c, [d, {:line, line}]}]) -> [{a, b, c, [d, {:line, line + template_line}]}] end).()
    IO.warn(message, stacktrace)
  end
end
