defmodule Surface.Translator.ComponentTranslatorUtils do
  alias Surface.Properties

  @callback translate(mod :: any, mod_str :: any, attributes :: any, directives :: any,
            children :: any, children_groups_contents :: any, caller :: any) :: iolist

  def add_render_call(renderer, args, has_children?) do
    ["<%= ", renderer, "(",  Enum.join(args, ", "), ") ", maybe_add("do ", has_children?), "%>"]
  end

  def maybe_add(value, condition) do
    if condition, do: value, else: ""
  end

  def add_require(mod_str) do
    ["<% require ", mod_str, " %>"]
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

    result =
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

    case result do
      {[], _} ->
        result
      {contents, attributes} ->
        {["\n" | contents], attributes}
    end
  end

  def split_data_children(children) do
    {data_children, children} =
      Enum.reduce(children, {%{}, []}, fn child, {data_children, children} ->
        with {_, _, _, %{module: module}} <- child,
             false <- is_nil(module),
             true <- function_exported?(module, :__group__, 0) do
          group = module.__group__()
          list = data_children[group] || []
          {Map.put(data_children, group, [child | list]), children}
        else
          _ -> {data_children, [child | children]}
        end
      end)
    {data_children, Enum.reverse(children)}
  end

  defp translate_data_children(children, func_bindings, bindings, caller) do
    for node <- children, reduce: {[], []} do
      {contents, translated_props_list} ->
        args =
          func_bindings
          |> Enum.map(&bindings[&1])
          |> Enum.join(", ")

        {name, attributes, node_children, %{module: module}} = node

        {var, content} = translate_children_content(args, node_children)

        {contents, attributes} =
          if var do
            attr = {"inner_content", {:attribute_expr, [var]}, caller.line}
            {[content, "\n" | contents], [attr | attributes]}
          else
            {contents, attributes}
          end

        translated_props =
          attributes
          |> Properties.translate_attributes(module, name, caller)
          |> Properties.wrap(name)

        {contents, [translated_props | translated_props_list]}
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
      "<% end %>"
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
