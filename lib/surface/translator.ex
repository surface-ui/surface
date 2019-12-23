defmodule Surface.Translator do
  @moduledoc """
  Defines a behaviour that must be implemented by all HTML/Surface node translators.

  This module also contains the main logic to translate Surface code.
  """

  # alias Surface.Translator.Parser
  import Surface.Translator.IO, only: [warn: 3]

  @callback translate(node :: any, caller: Macro.Env.t()) :: any

  @tag_directives [":for", ":if", ":debug"]

  @component_directives [":for", ":if", ":bindings", ":debug"]

  defmodule ParseError do
    defexception file: "", line: 0, message: "error parsing HTML/Surface"

    @impl true
    def message(exception) do
      "#{exception.file}:#{exception.line}: #{exception.message}"
    end
  end

  @doc """
  Translates a string written using the Surface format into a Phoenix template.
  """
  @spec run(binary, integer, Macro.Env.t(), binary) :: binary
  def run(string, line_offset, caller, file \\ "nofile") do
    string
    |> HTMLParser.parse()
    |> case do
      {:ok, nodes} ->
        nodes
      {:error, message, line} ->
        raise %ParseError{line: line + line_offset - 1, file: file, message: message}
    end
    |> build_metadata(caller)
    |> prepend_context()
    |> translate(caller)
    |> IO.iodata_to_binary()
  end

  @doc """
  Recursively translates nodes from a parsed surface code.
  """
  def translate(nodes, caller) when is_list(nodes) do
    for node <- nodes do
      translate(node, caller)
    end
  end

  def translate({tag, attributes, children, %{warn: message, line: line} = meta}, caller) do
    warn(message, caller, &(&1 + line))
    meta = Map.delete(meta, :warn)
    translate({tag, attributes, children, meta}, caller)
  end

  def translate({_, _, _, %{error: message, line: line}}, caller) do
    warn(message, caller, &(&1 + line))
    encoded_message = Plug.HTML.html_escape_to_iodata(message)
    ["<span style=\"color: red; border: 2px solid red; padding: 3px\"> Error: ", encoded_message, "</span>"]
  end

  def translate({:interpolation, expr}, _caller) do
    ["<%=", expr, "%>"]
  end

  def translate({_, _, _, %{translator: translator, module: mod}} = node, caller) do
    {mod_str, attributes, _, %{line: line}} = node
    validate_required_props(attributes, mod, mod_str, caller, line)

    translator.translate(node, caller)
    |> translate_directives(node, caller)
    |> Tuple.to_list()
  end

  def translate({_, _, _, %{translator: translator}} = node, caller) do
    translator.translate(node, caller)
    |> translate_directives(node, caller)
    |> Tuple.to_list()
  end

  def translate(node, _caller) do
    node
  end

  defp prepend_context(parsed_code) do
    ["<% context = assigns[:context] || %{} %><% _ = context %>" | parsed_code]
  end

  defp build_metadata([], _caller) do
    []
  end

  # TODO: Handle macros separately
  defp build_metadata([{<<first, _::binary>>, _, _, _} = node | nodes], caller)
      when first in ?A..?Z or first == ?# do
    {name, attributes, children, meta} = node
    {directives, attributes} = pop_directives(attributes, @component_directives)

    name =
      case name do
        "#" <> name -> name
        _ -> name
      end

    children = build_metadata(children, caller)

    meta =
      with {:ok, mod} <- actual_module(name, caller),
           {:ok, mod} <- check_module_loaded(mod, name),
           {:ok, mod} <- check_module_is_component(mod, name) do
        meta
        |> Map.put(:module, mod)
        |> Map.put(:translator, mod.translator())
        |> Map.put(:directives, directives)
      else
        {:error, message} ->
          Map.put(meta, :error, "cannot render <#{name}> (#{message})")
      end

    updated_node = {name, attributes, children, meta}
    [updated_node | build_metadata(nodes, caller)]
  end

  defp build_metadata([{tag_name, _, _, _} = node | nodes], caller) when is_binary(tag_name) do
    {_, attributes, children, meta} = node

    {directives, attributes} = pop_directives(attributes, @tag_directives)

    meta =
      meta
      |> Map.put(:translator, Surface.Translator.TagTranslator)
      |> Map.put(:directives, directives)

    children = build_metadata(children, caller)
    updated_node = {tag_name, attributes, children, meta}
    [updated_node | build_metadata(nodes, caller)]
  end

  defp build_metadata([node | nodes], caller) do
    [node | build_metadata(nodes, caller)]
  end

  defp build_metadata(nodes, _caller) do
    nodes
  end

  defp actual_module(mod_str, env) do
    {:ok, ast} = Code.string_to_quoted(mod_str)
    case Macro.expand(ast, env) do
      mod when is_atom(mod) ->
        {:ok, mod}
      _ ->
        {:error, "#{mod_str} is not a valid module name"}
    end
  end

  defp check_module_loaded(module, mod_str) do
    case Code.ensure_compiled(module) do
      {:module, mod} ->
        {:ok, mod}

      {:error, _reason} ->
        {:error, "module #{mod_str} could not be loaded"}
    end
  end

  defp check_module_is_component(module, mod_str) do
    if function_exported?(module, :translator, 0) do
      {:ok, module}
    else
      {:error, "module #{mod_str} is not a component"}
    end
  end

  defp validate_required_props(props, mod, mod_str, caller, line) do
    if function_exported?(mod, :__props__, 0) do
      existing_props = Enum.map(props, fn {key, _, _} -> String.to_atom(key) end)
      required_props = for p <- mod.__props__(), p.required, do: p.name
      missing_props = required_props -- existing_props

      for prop <- missing_props do
        message = "Missing required property \"#{prop}\" for component <#{mod_str}>"
        warn(message, caller, &(&1 + line))
      end
    end
  end

  defp translate_directives(parts, node, caller) do
    {_, _, _, %{directives: directives}} = node

    Enum.reduce(directives, parts, fn directive, acc ->
      handle_directive(directive, acc, node, caller)
    end)
  end

  defp handle_directive({":if", {:attribute_expr, [expr]}, _line}, parts, _node, _caller) do
    {open, children, close} = parts

    {
      ["<%= if ", String.trim(expr), " do %>", open],
      children,
      [close, "<% end %>"]
    }
  end

  defp handle_directive({":for", {:attribute_expr, [expr]}, _line}, parts, _node, _caller) do
    {open, children, close} = parts

    {
      ["<%= for ", String.trim(expr), " do %>", open],
      children,
      [close, "<% end %>"]
    }
  end

  defp handle_directive({":bindings", {:attribute_expr, [_expr]}, _line}, parts, _node, _caller) do
    parts
  end

  defp handle_directive({":debug", _value, _line}, parts, node, caller) do
    {_, _, _, %{line: line}} = node

    IO.puts ">>> DEBUG: #{caller.file}:#{caller.line + line}"
    parts
    |> Tuple.to_list()
    |> IO.iodata_to_binary()
    |> IO.puts
    IO.puts "<<<"

    parts
  end

  defp pop_directives(attributes, allowed_directives) do
    Enum.split_with(attributes, fn {attr, _, _} -> attr in allowed_directives end)
  end
end
