defmodule Surface.Parser do
  import NimbleParsec

  defmodule ParseError do
    defexception string: "", line: 0, col: 0, message: "error parsing HTML"

    def message(e) do
      """

      Failed to parse HTML: #{e.message}

      Check your syntax near line #{e.line}:

      #{e.string}
      """
    end
  end

  defp content_expr(expr) do
    expr
  end

  expr =
    string("<%")
    |> repeat(lookahead_not(string("%>")) |> utf8_char([]))
    |> string("%>")
    |> reduce({List, :to_string, []})

  attribute_expr =
    ignore(string("{"))
    |> repeat(lookahead_not(string("}")) |> utf8_char([]))
    |> ignore(string("}"))
    |> reduce({List, :to_string, []})
    |> tag(:attribute_expr)

  tag_name = ascii_string([?a..?z, ?0..?9, ?A..?Z, ?-, ?., ?_], min: 1)

  text =
    utf8_char(not: ?<)
    |> repeat(
      lookahead_not(
        choice([
          ignore(string("<")),
          ignore(string("<%"))
        ])
      )
      |> utf8_char([])
    )
    |> reduce({List, :to_string, []})

  whitespace = ascii_char([?\s, ?\n]) |> repeat() |> ignore()
  whitespace_no_ignore = ascii_char([?\s, ?\n]) |> repeat()

  closing_tag =
    ignore(string("</"))
    |> concat(tag_name)
    |> ignore(string(">"))
    |> unwrap_and_tag(:closing_tag)

  attribute_value =
    ignore(ascii_char([?"]))
    |> repeat(
      lookahead_not(ignore(ascii_char([?"])))
      |> choice([
        ~S(\") |> string() |> replace(?"),
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})

  attribute =
    tag_name
    |> concat(whitespace)
    |> optional(
      choice([
        ignore(string("=")) |> concat(attribute_expr),
        ignore(string("=")) |> concat(attribute_value)
      ])
    )
    |> line()

  opening_tag =
    ignore(string("<"))
    |> concat(tag_name)
    |> line()
    |> unwrap_and_tag(:opening_tag)
    |> repeat(whitespace |> concat(attribute)|> unwrap_and_tag(:attributes))
    |> concat(whitespace)

  comment =
    ignore(string("<!--"))
    |> repeat(lookahead_not(string("-->")) |> utf8_char([]))
    |> ignore(string("-->"))
    |> ignore()

  children =
    parsec(:parse_children)
    |> tag(:child)

  tag =
    opening_tag
    |> choice([
      ignore(string("/>")),
      ignore(string(">"))
      # |> concat(whitespace)
      |> concat(children)
      |> concat(closing_tag)
      # |> concat(whitespace)
    ])
    |> post_traverse(:validate_node)

  defparsecp(
    :parse_children,
    whitespace_no_ignore
    |> repeat(
      choice([
        tag,
        comment,
        expr |> map(:content_expr),
        text
      ])
    )
  )

  defparsecp(:parse_root, parsec(:parse_children) |> eos)

  defp validate_node(_rest, args, context, _line, _offset) do
    {[opening_tag], {line, _}} = Keyword.get(args, :opening_tag)
    closing_tag = Keyword.get(args, :closing_tag)

    cond do
      opening_tag == closing_tag or closing_tag == nil ->
        tag = opening_tag

        attributes =
          Keyword.get_values(args, :attributes)
          |> Enum.reverse()
          |> Enum.map(fn
            {[key], {line, _byte_offset}} ->
              {key, true, line}
            {[key, value], {line, _byte_offset}} ->
              {key, value, line}
          end)

        children =
          args
          |> Keyword.get_values(:child)
          |> Enum.reverse()

        {[{tag, attributes, children, line}], context}

      true ->
        {:error, "Closing tag #{closing_tag} did not match opening tag #{opening_tag}"}
    end
  end

  def parse(string, line_offset) do
    case parse_root(string) do
      {:ok, nodes, _, _, _, _} ->
        nodes

      {:error, reason, rest, _, {line, col}, _} ->
        raise %ParseError{
          string: String.split(rest, "\n") |> Enum.take(2) |> Enum.join("\n"),
          line: line + line_offset,
          col: col,
          message: reason
        }
    end
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
        warn(message, caller, line)
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
        warn("Missing required property \"#{prop}\" for component <#{mod_str}>", caller, line)
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

  def prepend_context(parsed_code) do
    ["<% context = %{} %><% _ = context %>" | parsed_code]
  end

  defp warn(message, caller, template_line) do
    stacktrace =
      Macro.Env.stacktrace(caller)
      |> (fn([{a, b, c, [d, {:line, line}]}]) -> [{a, b, c, [d, {:line, line + template_line}]}] end).()
    IO.warn(message, stacktrace)
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
    if Enum.find(props, fn {k, v, _} -> k in ["debug", :debug] && v == "true" end) do
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
