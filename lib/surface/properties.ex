defmodule Surface.Properties do

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :properties, accumulate: true)
    end
  end

  defmacro property({name, _, _}, type, opts \\ []) do
    property_ast(name, type, opts)
  end

  defp property_ast(name, type, opts) do
    default = Keyword.get(opts, :default)
    required = Keyword.get(opts, :required, false)
    group = Keyword.get(opts, :group)
    binding = Keyword.get(opts, :binding)
    use_bindings = Keyword.get(opts, :use_bindings, [])

    quote do
      doc = Module.get_attribute(__MODULE__, :doc)
      Module.delete_attribute(__MODULE__, :doc)

      # TODO: Validate opts based on the type
      @properties %{
        name: unquote(name),
        type: unquote(type),
        default: unquote(default),
        required: unquote(required),
        group: unquote(group),
        binding: unquote(binding),
        use_bindings: unquote(use_bindings),
        doc: doc
      }
    end
  end

  defmacro __before_compile__(env) do
    buildin_props = [:debug, :inner_content]
    props = Module.get_attribute(env.module, :properties)
    props_names = Enum.map(props, fn prop -> prop.name end) ++ buildin_props
    props_by_name = for p <- props, into: %{}, do: {p.name, p}

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

  # TODO: Move this to a new PropertyTranslator (or AttributeTranslator)
  def translate_attributes(attributes, mod, mod_str, caller, add_context \\ true) do
    if function_exported?(mod, :__props, 0) do
      props =
        for {key, value, line} <- attributes do
          key_atom = String.to_atom(key)
          prop = mod.__get_prop__(key_atom)
          if mod.__props() != [] && !mod.__validate_prop__(key_atom) do
            message = "Unknown property \"#{key}\" for component <#{mod_str}>"
            Surface.Translator.IO.warn(message, caller, &(&1 + line))
          end

          value = translate_value(prop[:type], value, caller, line)
          render_prop_value(key, value)
        end

        extra_props =
          if add_context do
            ["context: context"]
          else
            []
          end
      ["Surface.Properties.put_default_props(%{", Enum.join(props ++ extra_props, ", "), "}, #{inspect(mod)})"]
    else
      "%{}"
    end
  end

  def translate_value(:event, value, caller, line) do
    case value do
      {:attribute_expr, [_expr]} ->
        value
      event ->
        if Module.open?(caller.module) do
          event_reference = {to_string(event), caller.line + line}
          Module.put_attribute(caller.module, :event_references, event_reference)
        end
        event
    end
  end

  def translate_value(:list, {:attribute_expr, [expr]}, _caller, _line) do
    value =
      case String.split(expr, "<-") do
        [_lhs, value] ->
          value
        [value] ->
          value
      end
    {:attribute_expr, [value]}
  end

  def translate_value(:css_class, {:attribute_expr, [expr]}, _caller, _line) do
    # TODO: Validate expression

    new_expr =
      case String.trim(expr) do
        "[" <> _ ->
          expr
        _ ->
          "[#{expr}]"
    end
    {:attribute_expr, ["css_class(#{new_expr})"]}
  end

  def translate_value(_type, value, _caller, _line) when is_list(value) do
    for item <- value do
      case item do
        {:attribute_expr, [expr]} ->
          ["\#{", expr, "}"]
        _ ->
          item
      end
    end
  end

  def translate_value(_type, value, _caller, _line) do
    value
  end

  def put_default_props(props, mod) do
    Enum.reduce(mod.__props(), props, fn %{name: name, default: default}, acc ->
      Map.put_new(acc, name, default)
    end)
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

  def css_class(list) when is_list(list) do
    Enum.reduce(list, [], fn item, classes ->
      case item do
        {class, true} ->
          [to_kebab_case(class) | classes]
        class when is_binary(class) or is_atom(class) ->
          [to_kebab_case(class) | classes]
        _ ->
          classes
      end
    end) |> Enum.reverse() |> Enum.join(" ")
  end

  def css_class(value) when is_binary(value) do
    value
  end

  # TODO: Replace with a decent implementation
  defp to_kebab_case(value) do
    value
    |> to_string()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end
end
