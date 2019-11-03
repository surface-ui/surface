defmodule Surface.Translator.ComponentNode do
  defstruct [:name, :attributes, :children, :line, :module]
end

defimpl Surface.Translator.NodeTranslator, for: Surface.Translator.ComponentNode do
  alias Surface.Translator.Directive
  alias Surface.Properties
  import Surface.Translator.IO, only: [debug: 4, warn: 3]

  def translate(node, caller) do
    %{name: mod_str, attributes: attributes, line: line, module: mod} = node
    case validate_module(mod_str, mod) do
      {:ok, mod} ->
        validate_required_props(attributes, mod, mod_str, caller, line)
        do_translate(node, caller)
        |> debug(attributes, line, caller)

      {:error, message} ->
        warn(message, caller, &(&1 + line))
        render_error(message)
        |> debug(attributes, line, caller)
    end
  end

  defp do_translate(node, caller) do
    %{name: mod_str, attributes: attributes, children: children, module: mod} = node
    translator = mod.translator()
    {data_children, children} = split_data_children(children)
    {directives, attributes} = Directive.pop_directives(attributes)

    # TODO: Find a better approach for this. For now, if there's any
    # DataComponent and the rest of children are blank, we remove them.
    children =
      if data_children != %{} && String.trim(IO.iodata_to_binary(children)) == "" do
        []
      else
        children
      end
    has_children? = children != []

    {children_groups_contents, children_attributes} =
      translate_children_groups(mod, attributes, data_children, caller)

    translator.translate(mod, mod_str, attributes ++ children_attributes, directives, children, children_groups_contents, has_children?, caller)
  end

  defp validate_module(name, mod) do
    cond do
      mod == nil ->
        {:error, "Cannot render <#{name}> (module #{name} is not available)"}
      # TODO: Fix this so it does not depend on the existence of a function
      !function_exported?(mod, :translator, 0) && !function_exported?(mod, :data, 1) ->
        {:error, "Cannot render <#{name}> (module #{name} is not a component"}
      true ->
        {:ok, mod}
    end
  end

  defp validate_required_props(props, mod, mod_str, caller, line) do
    if function_exported?(mod, :__props, 0) do
      existing_props = Enum.map(props, fn {key, _, _} -> String.to_atom(key) end)
      required_props = for p <- mod.__props(), p.required, do: p.name
      missing_props = required_props -- existing_props

      for prop <- missing_props do
        message = "Missing required property \"#{prop}\" for component <#{mod_str}>"
        Surface.Translator.IO.warn(message, caller, &(&1 + line))
      end
    end
  end

  defp render_error(message) do
    encoded_message = Plug.HTML.html_escape_to_iodata(message)
    ["<span style=\"color: red; border: 2px solid red; padding: 3px\"> Error: ", encoded_message, "</span>"]
  end

  def split_data_children(children) do
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

  def translate_children_groups(_, _, [], _caller) do
    []
  end

  def translate_children_groups(module, attributes, data_children, caller) do
    bindings = find_bindings(module, attributes)
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

  def translate_data_children(children, func_bindings, bindings, caller) do
    for node <- children, reduce: {[], []} do
      {contents, translated_props_list} ->
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
        translated_props = Properties.translate_attributes([attr | node.attributes], node.module, node.name, caller, false)
        {[content | contents], [translated_props | translated_props_list]}
    end
  end

  def find_bindings(module, attributes) do
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

  def generate_var_id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> to_string()
  end
end

