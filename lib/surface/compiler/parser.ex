defmodule Surface.Compiler.Parser do
  @moduledoc false

  import NimbleParsec

  @doc """
  Parses a surface HTML document.
  """
  def parse(content) do
    case root(content, context: [macro: nil]) do
      {:ok, tree, "", %{macro: nil}, _, _} ->
        {:ok, tree}

      {:ok, _, rest, context, {line, _}, byte_offset} ->
        # Something went wrong then it has to be an error parsing the HTML tag.
        # However, because of repeat, the error is discarded, so we call node
        # again to get the proper error message.
        {:error, message, _rest, _context, {line, _col}, _byte_offset} =
          node(rest, context: context, line: line, byte_offset: byte_offset)

        {:error, message, line}

      {:error, message, _rest, _context, {line, _col}, _byte_offset} ->
        {:error, message, line}
    end
  end

  ## Common helpers
  defparsecp(
    :binary,
    string("\"")
    |> repeat(
      choice([
        string("\\\""),
        utf8_char(not: ?")
      ])
    )
    |> string("\"")
  )

  defparsecp(
    :charlist,
    string("\'")
    |> repeat(
      choice([
        string("\\'"),
        utf8_char(not: ?')
      ])
    )
    |> string("\'")
  )

  defparsecp(
    :tuple,
    string("{")
    |> repeat(
      choice([
        parsec(:tuple),
        parsec(:binary),
        parsec(:charlist),
        utf8_char(not: ?})
      ])
    )
    |> string("}")
  )

  expression =
    ignore(string("{{"))
    |> line()
    |> repeat(
      choice([
        parsec(:tuple),
        parsec(:binary),
        parsec(:charlist),
        lookahead_not(string("}}")) |> utf8_char([])
      ])
    )
    |> optional(string("}}"))

  tag =
    ascii_char([?a..?z, ?A..?Z])
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?., ?_], min: 0)
    |> reduce({List, :to_string, []})

  boolean =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])

  attribute_expr =
    expression
    |> post_traverse(:attribute_expr)

  attribute_value =
    ignore(ascii_char([?"]))
    |> repeat(
      lookahead_not(ignore(ascii_char([?"])))
      |> choice([
        ~S(\") |> string() |> replace(?"),
        attribute_expr,
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> wrap()
    |> post_traverse(:attribute_value)

  # Follow the rules of XML Names and Tokens plus "@" as a first char
  # https://www.w3.org/TR/2008/REC-xml-20081126/#NT-Name
  attr_start_char = ascii_string([?a..?z, ?A..?Z, ?_, ?:, ?@], 1)
  attr_name_char = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?:, ?-, ?., ??], min: 0)
  attr_name = attr_start_char |> concat(attr_name_char) |> reduce({Enum, :join, [""]})

  whitespace = ascii_string([?\s, ?\n], min: 0)

  attribute =
    whitespace
    |> concat(attr_name |> line())
    |> concat(whitespace)
    |> optional(
      choice([
        ignore(string("=")) |> concat(whitespace) |> concat(attribute_expr),
        ignore(string("=")) |> concat(whitespace) |> concat(attribute_value),
        ignore(string("=")) |> concat(whitespace) |> concat(integer(min: 1)),
        ignore(string("=")) |> concat(whitespace) |> concat(boolean)
      ])
    )
    |> wrap()

  comment =
    ignore(string("<!--"))
    |> repeat(lookahead_not(string("-->")) |> utf8_char([]))
    |> ignore(string("-->"))
    |> ignore()

  ## Void element node

  void_element =
    choice([
      string("area"),
      string("base"),
      string("br"),
      string("col"),
      string("command"),
      string("embed"),
      string("hr"),
      string("img"),
      string("input"),
      string("keygen"),
      string("link"),
      string("meta"),
      string("param"),
      string("source"),
      string("track"),
      string("wbr")
    ])

  void_element_node =
    ignore(string("<"))
    |> concat(void_element)
    |> line()
    |> concat(repeat(attribute) |> wrap())
    |> concat(whitespace)
    |> ignore(string(">"))
    |> wrap()
    |> post_traverse(:void_element_tags)

  defp void_element_tags(_rest, [[tag_node, attr_nodes, space]], context, _line, _offset) do
    {[tag], {line, _}} = tag_node
    attributes = build_attributes(attr_nodes)
    {[{tag, attributes, [], %{line: line, space: space}}], context}
  end

  ## Self-closing node

  self_closing_node =
    ignore(string("<"))
    |> concat(tag)
    |> line()
    |> concat(repeat(attribute) |> wrap())
    |> concat(whitespace)
    |> ignore(string("/>"))
    |> wrap()
    |> post_traverse(:self_closing_tags)

  defp self_closing_tags(_rest, [[tag_node, attr_nodes, space]], context, _line, _offset) do
    {[tag], {line, _}} = tag_node
    attributes = build_attributes(attr_nodes)
    {[{tag, attributes, [], %{line: line, space: space}}], context}
  end

  ## Regular node
  interpolation =
    expression
    |> post_traverse(:interpolation)

  text_with_interpolation = utf8_string([not: ?<, not: ?{], min: 1)

  opening_tag =
    ignore(string("<"))
    |> concat(tag)
    |> line()
    |> concat(repeat(attribute) |> wrap())
    |> concat(whitespace)
    |> ignore(string(">"))
    |> wrap()

  closing_tag = ignore(string("</")) |> concat(tag) |> ignore(string(">"))

  regular_node =
    opening_tag
    |> repeat(
      lookahead_not(string("</"))
      |> choice([
        parsec(:node),
        interpolation,
        string("{"),
        text_with_interpolation
      ])
    )
    |> wrap()
    |> optional(closing_tag)
    |> post_traverse(:match_tags)

  defp match_tags(
         _rest,
         [tag, [[{[tag], {opening_line, _}}, attr_nodes, space] | nodes]],
         context,
         _line,
         _offset
       ) do
    attributes = build_attributes(attr_nodes)
    {[{tag, attributes, nodes, %{line: opening_line, space: space}}], context}
  end

  defp match_tags(_rest, [closing, [[tag_node | _] | _]], _context, _line, _offset) do
    {[opening], {_opening_line, _}} = tag_node
    {:error, "closing tag #{inspect(closing)} did not match opening tag #{inspect(opening)}"}
  end

  defp match_tags(rest, [[[tag_node | _] | _]], _context, _line, _offset) do
    opening =
      case Regex.run(~r/^<(#?[a-zA-Z][a-zA-Z0-9_\-\.]+)/, rest) do
        [_, tag] ->
          tag

        _ ->
          {[tag], {_opening_line, _}} = tag_node
          tag
      end

    {:error, "expected closing tag for #{inspect(opening)}"}
  end

  defp interpolation(_rest, ["}}" | nodes], context, _line, _offset) do
    [{[], {opening_line, _}} | rest] = Enum.reverse(nodes)
    {[{:interpolation, IO.chardata_to_string(rest), %{line: opening_line}}], context}
  end

  defp interpolation(_rest, _, _context, _line, _offset),
    do: {:error, "expected closing for interpolation"}

  defp attribute_expr(_rest, ["}}" | nodes], context, _line, _offset) do
    [{[], {opening_line, _}} | rest] = Enum.reverse(nodes)
    {[{:attribute_expr, IO.chardata_to_string(rest), %{line: opening_line}}], context}
  end

  defp attribute_expr(_rest, _, _context, _line, _offset),
    do: {:error, "expected closing for attribute expression"}

  defp attribute_value(_rest, [nodes], context, _line, _offset) do
    value =
      case reduce_attribute_value(nodes, {[], []}) do
        [node] when not is_tuple(node) ->
          node

        [] ->
          ""

        nodes ->
          nodes
      end

    {[value], context}
  end

  defp reduce_attribute_value([], {[], result}) do
    Enum.reverse(result)
  end

  defp reduce_attribute_value([], {chars, result}) do
    new_node = chars |> Enum.reverse() |> IO.chardata_to_string()
    reduce_attribute_value([], {[], [new_node | result]})
  end

  defp reduce_attribute_value([{_, _, _} = node | nodes], {[] = chars, result}) do
    reduce_attribute_value(nodes, {chars, [node | result]})
  end

  defp reduce_attribute_value([{_, _, _} = node | nodes], {chars, result}) do
    new_node = chars |> Enum.reverse() |> IO.chardata_to_string()
    reduce_attribute_value(nodes, {[], [node, new_node | result]})
  end

  defp reduce_attribute_value([node | nodes], {chars, result}) do
    reduce_attribute_value(nodes, {[node | chars], result})
  end

  defp build_attributes(attr_nodes) do
    Enum.map(attr_nodes, fn
      # attribute without value (e.g. disabled)
      [space1, {[attr], {line, _}}, space2] ->
        {attr, true, %{line: line, spaces: [space1, space2]}}

      # attribute with value
      [space1, {[attr], {line, _}}, space2, space3, value] ->
        {attr, value, %{line: line, spaces: [space1, space2, space3]}}
    end)
  end

  ## Self-closing macro node

  self_closing_macro_node =
    ignore(string("<#"))
    |> concat(tag)
    |> line()
    |> concat(repeat(attribute) |> wrap())
    |> concat(whitespace)
    |> ignore(string("/>"))
    |> wrap()
    |> post_traverse(:prepend_hashtag)
    |> post_traverse(:self_closing_tags)

  defp prepend_hashtag(_rest, [[tag_node, attr_nodes, space]], context, _line, _offset) do
    {[tag], meta} = tag_node
    {[[{["#" <> tag], meta}, attr_nodes, space]], context}
  end

  ## Macro node

  text_without_interpolation = utf8_string([not: ?<], min: 1)

  opening_macro_tag =
    ignore(string("<#"))
    |> concat(tag)
    |> line()
    |> concat(repeat(attribute) |> wrap())
    |> concat(whitespace)
    |> ignore(string(">"))
    |> wrap()

  closing_macro_tag = ignore(string("</#")) |> concat(tag) |> ignore(string(">"))

  macro_node =
    opening_macro_tag
    |> post_traverse(:opening_macro_tag)
    |> repeat_while(choice([string("<"), text_without_interpolation]), :lookahead_macro_tag)
    |> wrap()
    |> optional(closing_macro_tag)
    |> post_traverse(:closing_macro_tag)

  defp opening_macro_tag(_rest, [macro], context, _, _) do
    {[], %{context | macro: macro}}
  end

  defp closing_macro_tag(
         _,
         [macro, rest],
         %{macro: [{[macro], {line, _}}, attr_nodes, space]} = context,
         _,
         _
       ) do
    tag = "#" <> macro
    attributes = build_attributes(attr_nodes)
    text = IO.iodata_to_binary(rest)
    {[{tag, attributes, [text], %{line: line, space: space}}], %{context | macro: nil}}
  end

  defp closing_macro_tag(
         _rest,
         _nodes,
         %{macro: [{[macro], {_line, _}}, _attr_nodes, _space]},
         _,
         _
       ) do
    {:error, "expected closing tag for #{inspect("#" <> macro)}"}
  end

  defp lookahead_macro_tag(rest, %{macro: macro} = context, _, _) do
    [{[macro], {_line, _}}, _attr_nodes, _space] = macro
    size = byte_size(macro)

    case rest do
      <<"</#", macro_match::binary-size(size), ">", _::binary>> when macro_match == macro ->
        {:halt, context}

      _ ->
        {:cont, context}
    end
  end

  defparsecp(
    :node,
    [
      void_element_node,
      macro_node,
      self_closing_macro_node,
      regular_node,
      self_closing_node,
      comment
    ]
    |> choice()
    |> label("opening HTML tag"),
    inline: true
  )

  defparsecp(
    :root,
    repeat(
      choice([
        interpolation,
        string("{"),
        text_with_interpolation,
        ascii_string([not: ?<], min: 1),
        parsec(:node)
      ])
    )
  )
end
