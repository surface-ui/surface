defmodule Surface.Translator.DefaultComponentTranslator do
  alias Surface.Properties
  alias Surface.Translator.NodeTranslator

  import Surface.Translator

  def translate(mod_str, attributes, children, mod, caller, opts) do
    {data_children, children} = split_data_children(children)

    # TODO: Find a better approach for this. For now, if there's any
    # DataComponent and the rest of children are blank, we remove them.
    children =
      if data_children != %{} && String.trim(IO.iodata_to_binary(children)) == "" do
        []
      else
        children
      end
    has_children? = children != []

    renderer = Keyword.fetch!(opts, :renderer)
    {children_content, children_attributes} =
      translate_children_groups(mod, attributes, data_children, caller)

    assigns_as_keyword = Keyword.get(opts, :assigns_as_keyword, false)
    rendered_props = Properties.render_props(attributes ++ children_attributes, mod, mod_str, caller)
    rendered_props = "Surface.Properties.put_default_props(#{rendered_props}, #{inspect(mod)})"
    rendered_props = if assigns_as_keyword, do: "Keyword.new(#{rendered_props})", else: rendered_props

    args = maybe_add_socket([mod_str, rendered_props], opts)

    # bindings = lazy_values(mod, attributes)
    [
      maybe_add_begin_context(mod, mod_str, rendered_props),
      children_content,
      "<%= ", renderer, "(",  Enum.join(args, ", "), ") ", maybe_add("do ", has_children?), "%>",
      # maybe_add_begin_lazy_content(bindings),
      maybe_add(NodeTranslator.translate(children, caller), has_children?),
      # maybe_add_end_lazy_content(bindings),
      maybe_add("<% end %>", has_children?),
      maybe_add_end_context(mod, mod_str, rendered_props)
    ]
  end

  defp maybe_add(value, add?) do
    if add?, do: value, else: ""
  end

  defp translate_children_groups(_, _, [], _caller) do
    []
  end

  defp translate_children_groups(module, attributes, data_children, caller) do
    bindings = find_bindings(module, attributes)
    for %{name: name, group: group, use_bindings: func_bindings} <- module.__props(),
        group != nil,
        reduce: {[], []} do
      {all_contents, new_attributes} ->
        # TODO: Warn if data_children[group] is nil
        {contents, rendered_props_list} = translate_data_children(data_children[group], func_bindings, bindings, caller)
        value = "[" <> Enum.join(rendered_props_list, ", ") <> "]"
        attr = {to_string(name), {:attribute_expr, [value]}, caller.line}
        {[contents | all_contents], [attr | new_attributes]}
    end
  end

  defp translate_data_children(children, func_bindings, bindings, caller) do
    for node <- children, reduce: {[], []} do
      {contents, rendered_props_list} ->
        args =
          func_bindings
          |> Enum.map(&bindings[&1])
          |> Enum.join(", ")

        # TODO: Generate a var name that's harder to conflict
        var = "content_" <> generate_var_id()

        content = [
          "<% ", var, " = fn ", args, " -> %>",
          node.children,
          "<% end %>\n"
        ]

        attr = {"inner_content", {:attribute_expr, [var]}, caller.line}
        rendered_props = Properties.render_props([attr | node.attributes], node.module, node.name, caller, false)
        {[content | contents], [rendered_props | rendered_props_list]}
    end
  end

  defp find_bindings(module, attributes) do
    # TODO: Warn if :binding is not defined and we have lhs
    for {name, {:attribute_expr, [expr]}, _line} <- attributes,
        [lhs, _] <- [String.split(expr, "<-")],
        prop_info = module.__get_prop__(String.to_atom(name)),
        prop_info.type == :list,
        prop_info.binding != nil,
        into: %{} do
      {prop_info.binding, String.trim(lhs)}
    end
  end

  defp split_data_children(children) do
    {data_children, children} =
      Enum.reduce(children, {%{}, []}, fn child, {data_children, children} ->
        if is_map(child) &&
           child.__struct__ == Surface.Translator.ComponentNode
           && function_exported?(child.module, :__group__, 0) do
          group = child.module.__group__()
          list = data_children[group] || []
          {Map.put(data_children, group, [child | list]), children}
        else
          {data_children, [child | children]}
        end
      end)
    {data_children, Enum.reverse(children)}
  end

  defp maybe_add_socket(args, opts) do
    if Keyword.fetch!(opts, :pass_socket) do
      ["@socket" | args]
    else
      args
    end
  end

  # defp lazy_values(mod, attributes) do
  #   for {key, value, _line} <- attributes, key in mod.__lazy_vars__() do
  #     value
  #   end
  # end

  defp generate_var_id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> to_string()
  end
end
