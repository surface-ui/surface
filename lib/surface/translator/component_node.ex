defmodule Surface.Translator.ComponentNode do
  defstruct [:name, :attributes, :children, :line, :module]
end

defimpl Surface.Translator.NodeTranslator, for: Surface.Translator.ComponentNode do
  import Surface.Translator

  def translate(node, caller) do
    %{name: mod_str, attributes: attributes, line: line, module: mod} = node
    case validate_module(mod_str, mod) do
      {:ok, mod} ->
        validate_required_props(attributes, mod, mod_str, caller, line)
        mod.render_code(node, caller)
        |> debug(attributes, line, caller)

      {:error, message} ->
        Surface.Translator.IO.warn(message, caller, &(&1 + line))
        render_error(message)
        |> debug(attributes, line, caller)
    end
  end

  defp validate_module(name, mod) do
    cond do
      mod == nil ->
        {:error, "Cannot render <#{name}> (module #{name} is not available)"}
      # TODO: Fix this so it does not depend on the existence of a function
      !function_exported?(mod, :render_code, 2) && !function_exported?(mod, :data, 1) ->
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
end

