defmodule Surface.Translator.ComponentTranslator do
  alias Surface.Properties

  @callback translate(mod :: any, mod_str :: any, attributes :: any, directives :: any,
            children :: any, children_groups_contents :: any, caller :: any) :: iolist

  def add_render_call(renderer, args, has_children?) do
    ["<%= ", renderer, "(",  Enum.join(args, ", "), ") ", maybe_add("do ", has_children?), "%>"]
  end

  def maybe_add(value, condition) do
    if condition, do: value, else: ""
  end

  def maybe_add_context_begin(mod, mod_str, rendered_props) do
    if function_exported?(mod, :begin_context, 1) do
      ["<% context = ", mod_str, ".begin_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end

  def maybe_add_context_end(mod, mod_str, rendered_props) do
    if function_exported?(mod, :end_context, 1) do
      ["<% context = ", mod_str, ".end_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end

  def translate_children(_, [], _caller) do
    {[], []}
  end

  def translate_children(directives, children, caller) do
    bindings = find_bindings(directives)
    {var, children_content} = translate_children_content(bindings, children)
    attr = {"inner_content", {:attribute_expr, [var]}, caller.line}

    {[children_content], [attr]}
  end

  def translate_children_groups(_, _, [], _caller) do
    {[], []}
  end

  def translate_children_groups(module, attributes, data_children, caller) do
    bindings = find_bindings_from_lists(module, attributes)
    for %{name: name, group: group, use_bindings: func_bindings} <- module.__props(),
        group != nil,
        reduce: {[], []} do
      {all_contents, new_attributes} ->
        # TODO: Warn if data_children[group] is nil
        {contents, translated_props_list} = translate_data_children(data_children[group], func_bindings, bindings, caller)
        value = "[" <> Enum.join(translated_props_list, ", ") <> "]"
        attr = {to_string(name), {:attribute_expr, [value]}, caller.line}
        {[contents | all_contents], [attr | new_attributes]}
    end
  end

  defp translate_data_children(children, func_bindings, bindings, caller) do
    for node <- children, reduce: {[], []} do
      {contents, translated_props_list} ->
        args =
          func_bindings
          |> Enum.map(&bindings[&1])
          |> Enum.join(", ")

        {var, content} = translate_children_content(args, node.children)

        if var do
          attr = {"inner_content", {:attribute_expr, [var]}, caller.line}
          translated_props = Properties.translate_attributes([attr | node.attributes], node.module, node.name, caller, false)
          {[content | contents], [translated_props | translated_props_list]}
        else
          {contents, translated_props_list}
        end
    end
  end

  defp translate_children_content(_args, []) do
    {nil, []}
  end

  defp translate_children_content(args, children) do
    # TODO: Generate a var name that's harder to conflict
    var = "content_" <> generate_var_id()

    content = [
      "<% ", var, " = fn ", args, " -> %>",
      children,
      "<% end %>\n"
    ]
    {var, content}
  end

  defp find_bindings_from_lists(module, attributes) do
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

  defp find_bindings(attributes) do
    case Enum.find(attributes, fn attr -> match?({":bindings", _, _}, attr) end) do
      {":bindings", {:attribute_expr, [expr]}, _line} ->
        String.trim(expr)
      _ ->
        "[]"
    end
  end

  defp generate_var_id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> to_string()
  end
end
