defmodule Surface.Translator.ComponentNode do
  alias Surface.Translator.Directive
  import Surface.Translator.IO, only: [debug: 4, warn: 3]

  def translate(node, caller) do
    {mod_str, attributes, _, %{line: line, module: mod}} = node
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
    {mod_str, attributes, children, %{module: mod}} = node
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

    translator.translate(mod, mod_str, attributes, directives, children, data_children, caller)
  end

  defp validate_module(name, mod) do
    cond do
      mod == nil ->
        {:error, "Cannot render <#{name}> (module #{name} is not available)"}
      # TODO: Fix this so it does not depend on the existence of a function
      Code.ensure_compiled?(mod) && !function_exported?(mod, :translator, 0) && !function_exported?(mod, :data, 1) ->
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
end

