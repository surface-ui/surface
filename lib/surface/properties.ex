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
    binding = Keyword.get(opts, :binding, false)
    lazy = Keyword.get(opts, :lazy, false)

    quote do
      doc = Module.get_attribute(__MODULE__, :doc)
      Module.delete_attribute(__MODULE__, :doc)

      @properties %{
        name: unquote(name),
        type: unquote(type),
        default: unquote(default),
        required: unquote(required),
        binding: unquote(binding),
        lazy: unquote(lazy),
        doc: doc
      }
    end
  end

  defmacro __before_compile__(env) do
    props = Module.get_attribute(env.module, :properties)
    props_names = Enum.map(props, fn prop -> prop.name end)
    props_by_name = for p <- props, into: %{}, do: {p.name, p}
    lazy_vars = for p <- props, p.lazy, do: to_string(p.name)

    quote do
      def __props() do
        unquote(Macro.escape(props))
      end

      def __lazy_vars__() do
        unquote(Macro.escape(lazy_vars))
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
      component_id = generate_component_id()
      Module.put_attribute(caller.module, :children, {component_id, mod})

      props =
        for {key, value, line} <- props do
          key_atom = String.to_atom(key)
          prop = mod.__get_prop__(key_atom)
          if mod.__props() != [] && !mod.__validate_prop__(key_atom) do
            message = "Invalid property \"#{key}\" for component <#{mod_str}>"
            Surface.IO.warn(message, caller, &(&1 + line))
          end
          value =
            if prop[:type] == :event do
              case value do
                {:attribute_expr, [_expr]} ->
                  value
                event ->
                  Module.put_attribute(caller.module, :event_references, {value, caller.line + line})
                  {:attribute_expr, ["event(\"#{event}\")"]}
              end
            else
              value
            end
          if prop[:binding] do
            # TODO: validate if it's a assign and show proper warning for line `caller.line + line`
            {:attribute_expr, ["@" <> mapped_binding]} = value
            Module.put_attribute(caller.module, :bindings, {{component_id, key_atom}, String.to_existing_atom(mapped_binding)})
          end
          render_prop_value(key, value)
        end ++ ["context: context, __component_id: concat_ids(assigns[:__component_id], \"#{component_id}\")"]
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
      value when is_integer(value) ->
        [key, ": ", to_string(value)]
      value when is_boolean(value) ->
        [key, ": ", inspect(value)]
      _ ->
        [key, ": ", ~S("), value, ~S(")]
    end
  end

  defp generate_component_id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> to_string()
  end
end
