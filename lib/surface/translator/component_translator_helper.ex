defmodule Surface.Translator.ComponentTranslatorHelper do
  @moduledoc false

  alias Surface.Properties
  alias Surface.Translator.DataComponentTranslator

  @callback translate(mod :: any, mod_str :: any, attributes :: any, directives :: any,
            children :: any, children_groups_contents :: any, caller :: any) :: iolist

  def add_render_call(renderer, args, has_children? \\ false) do
    ["<%= ", renderer, "(",  Enum.join(args, ", "), ") ", maybe_add("do ", has_children?), "%>"]
  end

  def maybe_add(value, condition) do
    if condition, do: value, else: ""
  end

  def add_require(mod_str) do
    ["<% require ", mod_str, " %>"]
  end

  def add_begin_context(mod, mod_str) do
    begin_context =
      if function_exported?(mod, :begin_context, 1) do
        ["<% context = ", mod_str, ".begin_context(Map.put(props, :context, context)) %>"]
      else
        ""
      end
    [begin_context, "<% props = Map.put(props, :context, context) %>"]
  end

  def add_end_context(mod, mod_str) do
    if function_exported?(mod, :begin_context, 1) do
      ["<% context = ", mod_str, ".end_context(props) %><% _ = context %>"]
    else
      ""
    end
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
        ""
    end
  end

  defp generate_var_id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> to_string()
  end

  def translate_children(mod, attributes, directives, children, caller) do
    parent_args = find_bindings(directives)
    prop_name_and_args_by_group = classify_prop_name_and_args_by_group(mod, attributes)

    {child_vars_by_prop_name, contents, temp_contents, has_inner_content?} =
      Enum.reduce(children, {%{}, [], [], false}, fn child, acc ->
        {child_vars_by_prop_name, contents, temp_contents, has_inner_content?} = acc
        case child do
          {_, _, _, %{translator: DataComponentTranslator, module: module}} ->

            {has_inner_content?, contents}
              = maybe_translate_inner_content(temp_contents, contents, has_inner_content?, parent_args)

            group = module.__group__()
            {prop_name, args} = prop_name_and_args_by_group[group]
            child_vars = child_vars_by_prop_name[prop_name] || []
            {child_var, content} = translate_child(child, args, caller)

            {
              Map.put(child_vars_by_prop_name, prop_name, [child_var | child_vars]),
              [content | contents],
              [],
              has_inner_content?
            }
          _ ->
            {child_vars_by_prop_name, contents, [child | temp_contents], has_inner_content?}
        end
      end)

    {has_inner_content?, contents} =
      maybe_translate_inner_content(temp_contents, contents, has_inner_content?, parent_args)

    children_props =
      for {prop_name, child_vars} <- child_vars_by_prop_name do
        [to_string(prop_name), ": [", Enum.join(Enum.reverse(child_vars), ", "), "]"]
      end

    children_props =
      if has_inner_content? do
        ["inner_content: inner_content" | children_props]
      else
        children_props
      end

    {children_props, Enum.reverse(contents)}
  end

  defp translate_child(node, args, caller) do
    {mod_str, attributes, children, %{module: mod, space: space}} = node

    # TODO: Generate names that are harder to conflict
    id = generate_var_id()
    props_id = "props_" <> id
    content_id = "content_" <> id
    var_id = "child_" <> id

    translated_props = Properties.translate_attributes(attributes, mod, mod_str, space, caller)

    translated_child = [
      "<% ", props_id, " = ", translated_props, " %>",
      "<% ", content_id, " = fn ", args, " -> %>",
      children,
      "<% end %>",
      "<% ", var_id, " = Map.put(", props_id, ", :inner_content, ", content_id, ") %>"
    ]
    {var_id, translated_child}
  end

  defp maybe_translate_inner_content(temp_contents, contents, has_inner_content?, args) do
    temp_contents = Enum.reverse(temp_contents)

    {inner_content_found?, translated} =
      if blank?(temp_contents) do
        {false, temp_contents}
      else
        {true, ["<% inner_content = fn ", args, " -> %>", temp_contents, "<% end %>"]}
      end

    {has_inner_content? || inner_content_found?, [translated | contents]}
  end

  defp classify_prop_name_and_args_by_group(mod, attributes) do
    bindings = find_bindings_from_lists(mod, attributes)

    for %{name: name, group: group, use_bindings: use_bindings} <- mod.__props__(), into: %{} do
      args =
        use_bindings
        |> Enum.map(&bindings[&1])
        |> Enum.join(", ")
      {group, {name, args}}
    end
  end

  @blanks ' \n\r\t\v\b\f\e\d\a'

  defp blank?([]), do: true

  defp blank?([h|t]), do: blank?(h) && blank?(t)

  defp blank?(""), do: true

  defp blank?(char) when char in @blanks, do: true

  defp blank?(<<h, t::binary>>) when h in @blanks, do: blank?(t)

  defp blank?(_), do: false
end
