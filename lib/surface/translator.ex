defmodule Surface.Translator do
  @moduledoc """
  Defines a behaviour that must be implemented by all HTML/Surface node translators.

  This module also contains the main logic to translate Surface code.
  """

  alias Surface.Translator.Parser
  import Surface.Translator.IO, only: [warn: 3]

  @callback prepare(nodes :: [any], caller: Macro.Env.t()) :: any

  @callback translate(node :: any, caller: Macro.Env.t()) :: any

  @optional_callbacks prepare: 2

  @tag_directives [":for", ":if", ":show", ":debug", ":props"]

  @component_directives [":for", ":if", ":let", ":debug", ":props"]

  @template_directives [":let"]

  defmodule ParseError do
    defexception file: "", line: 0, message: "error parsing HTML/Surface"

    @impl true
    def message(exception) do
      "#{Path.relative_to_cwd(exception.file)}:#{exception.line}: #{exception.message}"
    end
  end

  @doc """
  Translates a string written using the Surface format into a Phoenix template.
  """
  @spec run(binary, integer, Macro.Env.t(), binary) :: binary
  def run(string, line_offset, caller, file \\ "nofile") do
    string
    |> Parser.parse()
    |> case do
      {:ok, nodes} ->
        nodes

      {:error, message, line} ->
        raise %ParseError{line: line + line_offset - 1, file: file, message: message}
    end
    |> build_metadata(nil, caller)
    |> prepare(caller)
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

  def translate({_, _, _, %{error: message, line: line} = meta}, caller) do
    warn(message, caller, &(&1 + line))
    encoded_message = Plug.HTML.html_escape_to_iodata(message)
    require_code = if meta[:module], do: ["<% require ", meta[:module], " %>"], else: []

    [
      require_code,
      "<span style=\"color: red; border: 2px solid red; padding: 3px\"> Error: ",
      encoded_message,
      "</span>"
    ]
  end

  def translate({"slot", attributes, children, %{line: line}}, caller) do
    {name, props_expr} =
      Enum.reduce(attributes, {nil, ""}, fn
        {"name", value, _meta}, {_, props_expr} ->
          {List.to_atom(value), props_expr}

        {":props", {:attribute_expr, [expr]}, _meta}, {name, _} ->
          {name, String.trim(expr)}
      end)

    props_expr = if props_expr in [nil, ""], do: "[]", else: props_expr

    if name == "default" || name == nil do
      Module.put_attribute(caller.module, :used_slot, %{name: :default, line: line})

      [
        "<%= if assigns[:inner_content] do %>",
        "<%= @inner_content.(",
        props_expr,
        ") %>",
        "<% else %>",
        translate(children, caller),
        "<% end %>"
      ]
    else
      Module.put_attribute(caller.module, :used_slot, %{name: name, line: line})

      [
        "<%= if assigns[:#{name}] do %>",
        "<%= for slot <- @#{name} do %><%= slot.inner_content.(",
        props_expr,
        ") %><% end %>",
        "<% else %>",
        translate(children, caller),
        "<% end %>"
      ]
    end
  end

  def translate({:interpolation, expr, %{line: line}}, caller) do
    if String.contains?(expr, ["@inner_content(", ".inner_content("]) do
      file = Path.relative_to_cwd(caller.file)

      message = """
      the `inner_content` anonymous function should be called using the \
      dot-notation. Use `inner_content.()` instead of `inner_content()`\
      """

      raise %CompileError{line: caller.line + line, file: file, description: message}
    else
      ["<%=", expr, "%>"]
    end
  end

  def translate({_, _, _, %{translator: translator, module: mod}} = node, caller) do
    {mod_str, attributes, _, %{line: line}} = node
    validate_required_props(attributes, mod, mod_str, caller, line)

    translator.translate(node, caller)
    |> translate_directives(node, caller)
    |> Tuple.to_list()
  end

  def translate({_, _, _, %{translator: translator}} = node, caller) do
    translate_pre_directives(node, caller)
    |> translator.translate(caller)
    |> translate_directives(node, caller)
    |> Tuple.to_list()
  end

  def translate(node, _caller) do
    node
  end

  defp prepare(nodes, caller) do
    with translator <- get_component_translator(caller.module),
         {:module, _} <- Code.ensure_compiled(translator),
         true <- function_exported?(translator, :prepare, 2) do
      translator.prepare(nodes, caller)
    else
      _ ->
        nodes
    end
  end

  defp get_component_translator(module) do
    cond do
      Module.open?(module) ->
        Module.get_attribute(module, :translator)

      function_exported?(module, :translator, 0) ->
        module.translator()

      true ->
        nil
    end
  end

  defp prepend_context(parsed_code) do
    ["<% context = assigns[:__surface_context__] || %{} %><% _ = context %>" | parsed_code]
  end

  defp build_metadata([], _parent_key, _caller) do
    []
  end

  # TODO: Handle macros separately
  defp build_metadata([{<<first, _::binary>>, _, _, _} = node | nodes], parent_key, caller)
       when first in ?A..?Z or first == ?# do
    {name, attributes, children, meta} = node
    {directives, attributes} = pop_directives(attributes, @component_directives)

    name =
      case name do
        "#" <> name -> name
        _ -> name
      end

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
          meta
          |> Map.put(:module, nil)
          |> Map.put(:error, "cannot render <#{name}> (#{message})")
      end

    with true <- function_exported?(meta.module, :__slot_name__, 0),
         slot <- meta.module.__slot_name__(),
         true <- slot != nil do
      put_assigned_slot(caller, slot, parent_key)
    else
      _ ->
        put_assigned_slot(caller, :default, parent_key)
    end

    node_id = :erlang.unique_integer([:positive, :monotonic])
    node_key = {meta.module, node_id, caller.line + meta.line}
    init_assigned_slots(caller, node_key)
    children = build_metadata(children, node_key, caller)

    updated_node = {name, attributes, children, meta}
    [updated_node | build_metadata(nodes, nil, caller)]
  end

  defp build_metadata([{"template" = tag_name, _, _, _} = node | nodes], parent_key, caller) do
    {_, attributes, children, meta} = node
    {directives, attributes} = pop_directives(attributes, @template_directives)

    meta =
      case find_attribute_and_line(attributes, "slot") do
        {slot, slot_line} ->
          put_assigned_slot(caller, slot, parent_key)

          meta
          |> Map.put(:translator, Surface.Translator.SlotTranslator)
          |> Map.put(:slot, {slot, slot_line})
          |> Map.put(:module, nil)
          |> Map.put(:directives, directives)

        _ ->
          put_assigned_slot(caller, :default, parent_key)

          meta
          |> Map.put(:translator, Surface.Translator.TagTranslator)
          |> Map.put(:directives, directives)
      end

    children = build_metadata(children, parent_key, caller)
    updated_node = {tag_name, attributes, children, meta}
    [updated_node | build_metadata(nodes, parent_key, caller)]
  end

  defp build_metadata([{tag_name, _, _, _} = node | nodes], parent_key, caller)
       when is_binary(tag_name) do
    {_, attributes, children, meta} = node
    {directives, attributes} = pop_directives(attributes, @tag_directives)

    put_assigned_slot(caller, :default, parent_key)

    meta =
      meta
      |> Map.put(:translator, Surface.Translator.TagTranslator)
      |> Map.put(:directives, directives)

    children = build_metadata(children, parent_key, caller)
    updated_node = {tag_name, attributes, children, meta}
    [updated_node | build_metadata(nodes, parent_key, caller)]
  end

  defp build_metadata([node | nodes], parent_key, caller) do
    if !Surface.Translator.ComponentTranslatorHelper.blank?(node) do
      put_assigned_slot(caller, :default, parent_key)
    end

    [node | build_metadata(nodes, parent_key, caller)]
  end

  defp build_metadata(nodes, _pareint_node_id, _caller) do
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
      required_props = for p <- mod.__props__(), Keyword.get(p.opts, :required, false), do: p.name
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

  defp translate_pre_directives(node, caller) do
    {_, _, _, %{directives: directives}} = node

    Enum.reduce(directives, node, fn directive, acc ->
      handle_pre_directive(directive, acc, caller)
    end)
  end

  defp handle_pre_directive({":show", {:attribute_expr, [dir_expr]}, dir_meta}, node, _caller) do
    {mod_str, attributes, children, meta} = node

    build_style_attr = fn value, meta ->
      {"style", value, Map.put(meta, :directive_show_expr, dir_expr)}
    end

    {updated_attributes, found} =
      Enum.reduce(attributes, {[], false}, fn
        {"style", value, meta}, {attrs, _found} ->
          attr = build_style_attr.(value, meta)
          {[attr | attrs], true}

        attr, {attrs, found} ->
          {[attr | attrs], found}
      end)

    updated_attributes =
      if found do
        updated_attributes
      else
        attr = build_style_attr.("", dir_meta)
        [attr | updated_attributes]
      end

    {mod_str, Enum.reverse(updated_attributes), children, meta}
  end

  defp handle_pre_directive({name, _, %{line: line}}, node, caller) do
    {tag_name, _, _, %{translator: translator}} = node

    if (translator == Surface.Translator.TagTranslator && name not in @tag_directives) ||
         (translator == Surface.Translator.ComponentTranslator &&
            name not in @component_directives) do
      warn("unknown directive #{inspect(name)} for <#{tag_name}>", caller, &(&1 + line))
    end

    node
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

  defp handle_directive({":let", {:attribute_expr, [_expr]}, _line}, parts, _node, _caller) do
    parts
  end

  defp handle_directive({":props", {:attribute_expr, [expr]}, _line}, parts, node, _caller) do
    {open, children, close} = parts
    {_, _, _, %{translator: translator}} = node

    case translator do
      Surface.Translator.ComponentTranslator ->
        {
          List.insert_at(
            open,
            2,
            [
              "<% props = Map.put(props, :__dynamic_props__,",
              String.trim(expr),
              ") %>"
            ]
          ),
          children,
          close
        }

      Surface.Translator.TagTranslator ->
        dynamic_props =
          ~S[<%= Enum.map(assigns.__dynamic_props__, fn {key, val} -> " #{key}=#{val}" end) %>]

        {
          List.insert_at(open, 3, dynamic_props),
          children,
          close
        }

      _ ->
        parts
    end
  end

  defp handle_directive({":debug", _value, _line}, parts, node, caller) do
    {_, _, _, %{line: line}} = node

    IO.puts(">>> DEBUG: #{caller.file}:#{caller.line + line}")

    parts
    |> Tuple.to_list()
    |> IO.iodata_to_binary()
    |> IO.puts()

    IO.puts("<<<")

    parts
  end

  defp handle_directive(_, parts, _node, _caller) do
    parts
  end

  defp pop_directives(attributes, allowed_directives) do
    Enum.split_with(attributes, fn {attr, _, _} -> attr in allowed_directives end)
  end

  defp find_attribute_and_line(attributes, name) do
    Enum.find_value(attributes, fn {attr_name, value, %{line: line}} ->
      if name == attr_name do
        {List.to_atom(value), line}
      end
    end)
  end

  defp init_assigned_slots(caller, parent_key) do
    {mod, _, _} = parent_key

    if Module.open?(caller.module) && function_exported?(mod, :__slots__, 0) do
      assigned_slots_by_parent =
        Module.get_attribute(caller.module, :assigned_slots_by_parent) || %{}

      assigned_slots_by_parent = Map.put(assigned_slots_by_parent, parent_key, MapSet.new())
      Module.put_attribute(caller.module, :assigned_slots_by_parent, assigned_slots_by_parent)
    end
  end

  defp put_assigned_slot(caller, slot, parent_key) do
    if parent_key && Module.open?(caller.module) do
      assigned_slots_by_parent = Module.get_attribute(caller.module, :assigned_slots_by_parent)

      assigned_slots_by_parent =
        Map.update(assigned_slots_by_parent, parent_key, MapSet.new([slot]), fn slots ->
          MapSet.put(slots, slot)
        end)

      Module.put_attribute(caller.module, :assigned_slots_by_parent, assigned_slots_by_parent)
    end
  end
end
