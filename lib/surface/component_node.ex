defmodule Surface.ComponentNode do
  import Surface.Translator
  alias Surface.NodeTranslator

  defstruct [:name, :attributes, :children, :line]

  defimpl NodeTranslator do
    def translate(node, caller) do
      %{name: mod_str, attributes: attributes, children: children, line: line} = node
      case validate_module(mod_str, caller) do
        {:ok, mod} ->
          validate_required_props(attributes, mod, mod_str, caller, line)
          mod.render_code(mod_str, attributes, children, mod, caller)
          |> debug(attributes, line, caller)

        {:error, message} ->
          Surface.IO.warn(message, caller, &(&1 + line))
          render_error(message)
          |> debug(attributes, line, caller)
      end
    end

    defp validate_module(mod_str, caller) do
      mod = actual_module(mod_str, caller)
      cond do
        !Code.ensure_compiled?(mod) ->
          {:error, "Cannot render <#{mod_str}> (module #{mod_str} is not available)"}
        !function_exported?(mod, :render_code, 5) ->
          {:error, "Cannot render <#{mod_str}> (module #{mod_str} is not a component"}
        true ->
          {:ok, mod}
      end
    end

    defp actual_module(mod_str, env) do
      {:ok, ast} = Code.string_to_quoted(mod_str)
      Macro.expand(ast, env)
    end

    defp validate_required_props(props, mod, mod_str, caller, line) do
      if function_exported?(mod, :__props, 0) do
        existing_props = Enum.map(props, fn {key, _, _} -> String.to_atom(key) end)
        required_props = for p <- mod.__props(), p.required, do: p.name
        missing_props = required_props -- existing_props

        for prop <- missing_props do
          message = "Missing required property \"#{prop}\" for component <#{mod_str}>"
          Surface.IO.warn(message, caller, &(&1 + line))
        end
      end
    end

    defp render_error(message) do
      encoded_message = Plug.HTML.html_escape_to_iodata(message)
      ["<span style=\"color: red; border: 2px solid red; padding: 3px\"> Error: ", encoded_message, "</span>"]
    end
  end
end
