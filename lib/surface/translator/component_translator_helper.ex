defmodule Surface.Translator.ComponentTranslatorHelper do
  @moduledoc false

  alias Surface.Translator.DataComponentTranslator

  def add_render_call(renderer, args, has_children? \\ false) do
    ["<%= ", renderer, "(",  Enum.join(args, ", "), ") ", maybe_add("do ", has_children?), "%>"]
  end

  def maybe_add(value, condition) do
    if condition, do: value, else: ""
  end

  def add_require(mod_str) do
    ["<% require ", mod_str, " %>"]
  end

  def add_begin_context(_mod, mod_str) do
    ["<% {props, context} = begin_context(props, context, ", mod_str, ") %>"]
  end

  def add_end_context(_mod, mod_str) do
    ["<% context = end_context(context, ", mod_str, ") %><% _ = context %>"]
  end

  def maybe_add_fallback_content(condition) do
    maybe_add([
      "<% {prop, i, arg} -> %>",
      ~S[<%= raise "no matching content function for #{inspect(prop)}\##{i} with argument #{inspect(arg)}" %>]
    ], condition)
  end

  defp find_bindings_from_lists(module, attributes) do
    # TODO: Warn if :binding is not defined and we have lhs
    for {name, {:attribute_expr, [expr]}, _line} <- attributes,
        [lhs, _] <- [String.split(expr, "<-")],
        prop_info = module.__get_prop__(String.to_atom(name)),
        prop_info.type == :list,
        binding = prop_info.opts[:binding],
        into: %{} do
      {binding, String.trim(lhs)}
    end
  end

  defp find_bindings(attributes) do
    case Enum.find(attributes, fn attr -> match?({":bindings", _, _}, attr) end) do
      {":bindings", {:attribute_expr, [expr]}, _line} ->
        String.trim(expr)
      _ ->
        ""
    end
  end

  def translate_children(mod, attributes, directives, children, caller) do
    opts = %{
      parent_args: find_bindings(directives),
      slots_with_args: get_slots_with_args(mod, attributes),
      caller: caller
    }

    init_slots_meta = %{__default__: %{size: 0, binding: opts.parent_args != ""}}

    {slots_props, slots_meta, contents, _temp_contents, _opts} =
      children
      |> Enum.reduce({%{}, init_slots_meta, [], [], opts}, &handle_child/2)
      |> maybe_add_default_content()

    children_props =
      for {prop_name, value} <- slots_props do
        [to_string(prop_name), ": [", Enum.join(Enum.reverse(value), ", "), "]"]
      end

    {children_props, inspect(slots_meta), Enum.reverse(contents)}
  end

  def translate_attributes(attributes, mod, mod_str, space, caller, opts \\ []) do
    put_default_props = Keyword.get(opts, :put_default_props, true)

    if function_exported?(mod, :__props__, 0) do
      translated_values =
        Enum.reduce(attributes, [], fn {key, value, %{line: line, spaces: spaces}}, translated_values ->
          key_atom = String.to_atom(key)
          prop = mod.__get_prop__(key_atom)
          if mod.__props__() != [] && !mod.__validate_prop__(key_atom) do
            message = "Unknown property \"#{key}\" for component <#{mod_str}>"
            Surface.Translator.IO.warn(message, caller, &(&1 + line))
          end

          value = translate_value(prop[:type], key, value, caller, line)
          [{key, value, spaces, ","} | translated_values]
        end)

      translated_values =
        case translated_values do
          [{key, value, spaces, _} | rest] ->
            [{key, value, spaces, ""} | rest]

          _ ->
            translated_values
        end

      translated_props =
        Enum.reduce(translated_values, [], fn {key, value, spaces, comma}, translated_props ->
          [translate_prop(key, value, spaces, comma) | translated_props]
        end)

      props = ["%{", translated_props, space, "}"]

      if put_default_props do
        ["put_default_props(", props, ", ", mod_str, ")"]
      else
        props
      end
    else
      "%{}"
    end
  end

  def translate_value(:event, key, value, caller, line) do
    case value do
      {:attribute_expr, [expr]} ->
        {:attribute_expr, ["event_value(\"#{key}\", [#{expr}], assigns[:__surface_cid__])"]}

      event ->
        if Module.open?(caller.module) do
          event_reference = {to_string(event), caller.line + line}
          Module.put_attribute(caller.module, :event_references, event_reference)
        end
        {:attribute_expr, ["event_value(\"#{key}\", \"#{event}\", assigns[:__surface_cid__])"]}
    end
  end

  def translate_value(:list, _key, {:attribute_expr, [expr]}, _caller, _line) do
    value =
      case String.split(expr, "<-") do
        [_lhs, value] ->
          value
        [value] ->
          value
      end
    {:attribute_expr, [value]}
  end

  def translate_value(:css_class, _key, {:attribute_expr, [expr]}, _caller, _line) do
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

  def translate_value(_type, _key, value, _caller, _line) when is_list(value) do
    for item <- value do
      case item do
        {:attribute_expr, [expr]} ->
          ["\#{", expr, "}"]
        _ ->
          item
      end
    end
  end

  def translate_value(_type, _key, value, _caller, _line) do
    value
  end

  @blanks ' \n\r\t\v\b\f\e\d\a'

  def blank?([]), do: true

  def blank?([h|t]), do: blank?(h) && blank?(t)

  def blank?(""), do: true

  def blank?(char) when char in @blanks, do: true

  def blank?(<<h, t::binary>>) when h in @blanks, do: blank?(t)

  def blank?(_), do: false

  defp handle_child({_, _, _, %{translator: DataComponentTranslator}} = child, acc) do
    {mod_str, attributes, children, %{module: module, space: space}} = child
    {slots_props, slots_meta, contents, _, opts} = maybe_add_default_content(acc)

    slot_name = module.__slot_name__()
    content_args = opts.slots_with_args[slot_name]

    slots_meta = Map.put_new(slots_meta, slot_name, %{size: 0})
    meta = slots_meta[slot_name]
    args = if content_args == "", do: "_args", else: content_args
    content = ["<% {", inspect(slot_name), ", ", to_string(meta.size), ", ", args, "} -> %>", children]
    slots_meta = Map.put(slots_meta, slot_name, %{size: meta.size + 1, binding: content_args != ""})

    slots_props = Map.put_new(slots_props, slot_name, [])
    props = translate_attributes(attributes, module, mod_str, space, opts.caller)
    slots_props = Map.update(slots_props, slot_name, [], &[props|&1])

    {slots_props, slots_meta, [content | contents], [], opts}
  end

  defp handle_child(child, acc) do
    {slots_props, slots_meta, contents, temp_contents, opts} = acc
    {slots_props, slots_meta, contents, [child | temp_contents], opts}
  end

  defp maybe_add_default_content(acc) do
    {slots_props, slots_meta, contents, temp_contents, opts} = acc

    {slots_meta, contents} =
      if blank?(temp_contents) do
        {slots_meta, [Enum.reverse(temp_contents) | contents]}
      else
        meta = slots_meta[:__default__]
        args = if opts.parent_args == "", do: "_args", else: opts.parent_args
        content = ["<% {:__default__, ", to_string(meta.size), ", ", args, "} -> %>", Enum.reverse(temp_contents)]
        slots_meta = update_in(slots_meta, [:__default__, :size], &(&1 + 1))
        {slots_meta, [content | contents]}
      end

    {slots_props, slots_meta, contents, [], opts}
  end

  defp get_slots_with_args(mod, attributes) do
    bindings = find_bindings_from_lists(mod, attributes)

    for %{name: name, opts: opts} <- mod.__slots__(),
        use_bindings = Keyword.get(opts, :use_bindings, []),
        into: %{} do
      args =
        use_bindings
        |> Enum.map(&bindings[&1])
        |> Enum.join(", ")
      {name, args}
    end
  end

  defp translate_prop(key, value, spaces, comma) do
    rhs =
      case value do
        {:attribute_expr, value} ->
          expr = value |> IO.iodata_to_binary() |> String.trim()
          ["(", expr, ")"]
        value when is_integer(value) ->
          to_string(value)
        value when is_boolean(value) ->
          inspect(value)
        _ ->
          [~S("), value, ~S(")]
      end

    case spaces do
      [space1, space2, space3] ->
        space = space2 <> space3
        space = if space != "", do: space, else: " "
        [space1, key, ":", space, rhs, comma]

      [space1, space2] ->
        [space1, key, ": ", rhs, comma, space2]
    end
  end
end
