defmodule Surface.Translator.ComponentTranslatorHelper do
  @moduledoc false

  alias Surface.Properties
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

  def translate_children(mod, attributes, directives, children, caller) do
    opts = %{
      parent_args: find_bindings(directives),
      prop_name_and_args_by_group: classify_prop_name_and_args_by_group(mod, attributes),
      caller: caller
    }

    init_groups_meta = %{__default__: %{size: 0, binding: opts.parent_args != ""}}

    {groups_props, groups_meta, contents, _temp_contents, _opts} =
      children
      |> Enum.reduce({%{}, init_groups_meta, [], [], opts}, &handle_child/2)
      |> maybe_add_default_content()

    children_props =
      for {prop_name, value} <- groups_props do
        [to_string(prop_name), ": [", Enum.join(Enum.reverse(value), ", "), "]"]
      end

    {children_props, inspect(groups_meta), Enum.reverse(contents)}
  end

  defp handle_child({_, _, _, %{translator: DataComponentTranslator}} = child, acc) do
    {mod_str, attributes, children, %{module: module, space: space}} = child
    {groups_props, groups_meta, contents, _, opts} = maybe_add_default_content(acc)

    group = module.__group__()
    {prop_name, content_args} = opts.prop_name_and_args_by_group[group]

    groups_meta = Map.put_new(groups_meta, prop_name, %{size: 0})
    meta = groups_meta[prop_name]
    args = if content_args == "", do: "_args", else: content_args
    content = ["<% {", inspect(prop_name), ", ", to_string(meta.size), ", ", args, "} -> %>", children]
    groups_meta = Map.put(groups_meta, prop_name, %{size: meta.size + 1, binding: content_args != ""})

    groups_props = Map.put_new(groups_props, prop_name, [])
    props = Properties.translate_attributes(attributes, module, mod_str, space, opts.caller)
    groups_props = Map.update(groups_props, prop_name, [], &[props|&1])

    {groups_props, groups_meta, [content | contents], [], opts}
  end

  defp handle_child(child, acc) do
    {groups_props, groups_meta, contents, temp_contents, opts} = acc
    {groups_props, groups_meta, contents, [child | temp_contents], opts}
  end

  defp maybe_add_default_content(acc) do
    {groups_props, groups_meta, contents, temp_contents, opts} = acc

    {groups_meta, contents} =
      if blank?(temp_contents) do
        {groups_meta, [Enum.reverse(temp_contents) | contents]}
      else
        meta = groups_meta[:__default__]
        args = if opts.parent_args == "", do: "_args", else: opts.parent_args
        content = ["<% {:__default__, ", to_string(meta.size), ", ", args, "} -> %>", Enum.reverse(temp_contents)]
        groups_meta = update_in(groups_meta, [:__default__, :size], &(&1 + 1))
        {groups_meta, [content | contents]}
      end

    {groups_props, groups_meta, contents, [], opts}
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
