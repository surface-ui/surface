defmodule Surface.Translator do

  def translate(string, line_offset, caller) do
    string
    |> Surface.Parser.parse(line_offset)
    |> prepend_context()
    |> to_iolist(caller)
    |> IO.iodata_to_binary()
  end

  defp prepend_context(parsed_code) do
    ["<% context = %{} %><% _ = context %>" | parsed_code]
  end

  def to_iolist(nodes, caller) when is_list(nodes) do
    for node <- nodes do
      to_iolist(node, caller)
    end
  end

  def to_iolist({<<first, _::binary>> = mod_str, attributes, children, line}, caller) when first in ?A..?Z do
    case validate_module(mod_str, caller) do
      {:ok, mod} ->
        validate_required_props(attributes, mod, mod_str, caller, line)
        # validate_children(mod, children)
        mod.render_code(mod_str, attributes, to_iolist(children, caller), mod, caller)
        |> debug(attributes, line, caller)

      {:error, message} ->
        Surface.IO.warn(message, caller, &(&1 + line))
        render_error(message)
        |> debug(attributes, line, caller)
    end
  end

  def to_iolist({tag_name, attributes, [], line}, caller) when is_binary(tag_name) do
    ["<", tag_name, render_tag_props(attributes), "/>"]
    |> debug(attributes, line, caller)
  end

  def to_iolist({tag_name, attributes, children, line}, caller) when is_binary(tag_name) do
    [
      ["<", tag_name, render_tag_props(attributes), ">"],
      to_iolist(children, caller),
      ["</", tag_name, ">"]
    ] |> debug(attributes, line, caller)
  end

  # def to_iolist(node, _caller) when is_binary(node) do
  def to_iolist(node, _caller) do
    node
  end

  defp render_tag_props(props) do
    for {key, value, _line} <- props do
      render_tag_prop_value(key, value)
    end
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

  defp render_tag_prop_value(key, value) do
    case value do
      {:attribute_expr, value} ->
        expr = value |> IO.iodata_to_binary() |> String.trim()
        [" ", key, "=", ~S("), "<%= ", expr, " %>", ~S(")]
      _ ->
        [" ", key, "=", ~S("), value, ~S(")]
    end
  end

  defp actual_module(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)
    Macro.expand(ast, env)
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

  defp debug(iolist, props, line, caller) do
    if Enum.find(props, fn {k, v, _} -> k in ["debug", :debug] && v end) do
      IO.puts ">>> DEBUG: #{caller.file}:#{caller.line + line}"
      iolist
      |> IO.iodata_to_binary()
      |> IO.puts
      IO.puts "<<<"
    end
    iolist
  end

  def render_error(message) do
    encoded_message = Plug.HTML.html_escape_to_iodata(message)
    ["<span style=\"color: red; border: 2px solid red; padding: 3px\"> Error: ", encoded_message, "</span>"]
  end

end
