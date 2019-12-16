defmodule HTMLParser do
  import NimbleParsec

  # TODO: use line+line_offset+byte_offset in parse/1 for error reporting
  # TODO: add atributes spaces in metadata
  # TODO: interpolation in attribute value
  # TODO: add support for comments
  # TODO: add support for attributes in macro components

  @doc """
  Parses a surface HTML document.
  """
  def parse(content) do
    case node(content, context: [macro: nil]) do
      {:ok, tree, rest, %{macro: nil}, _, _} ->
        if blank?(rest) do
          {:ok, tree}
        else
          {:error, "expected end of string, found: #{inspect(rest)}"}
        end

      {:error, message, _rest, _context, _line_offset, _byte_offset} ->
        {:error, message}
    end
  end

  ## Common helpers

  tag =
    ascii_char([?a..?z, ?A..?Z])
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?., ?_], min: 0)
    |> reduce({List, :to_string, []})

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
    |> wrap()

  attr_name = ascii_string([?a..?z, ?0..?9, ?A..?Z, ?-, ?., ?_, ?:], min: 1)
  whitespace = ascii_char([?\s, ?\n]) |> repeat()

  attribute =
    attr_name
    |> concat(whitespace)
    |> optional(
      choice([
        ignore(string("=")) |> concat(attribute_value),
        ignore(string("=")) |> concat(integer(min: 1)),
      ])
    )
    |> line()

  ## Self-closing node

  self_closing_node =
    ignore(string("<"))
    |> concat(tag)
    |> repeat(whitespace |> concat(attribute))
    |> concat(whitespace)
    |> ignore(string("/>"))
    |> wrap()
    |> post_traverse(:self_closing_tags)

  defp self_closing_tags(_rest, [[tag | attr_nodes]], context, _line, _offset) do
    {attributes, _spaces} = split_attributes_and_spaces(attr_nodes)
    {[{tag, Enum.reverse(attributes), []}], context}
  end

  ## Regular node

  interpolation =
    ignore(string("{{"))
    |> repeat(lookahead_not(string("}}")) |> utf8_char([]))
    |> optional(string("}}"))
    |> post_traverse(:interpolation)

  text_with_interpolation = utf8_string([not: ?<, not: ?{], min: 1)

  opening_tag =
    ignore(string("<"))
    |> concat(tag)
    |> repeat(whitespace |> concat(attribute))
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

  defp match_tags(_rest, [tag, [[tag | attr_nodes] | nodes]], context, _line, _offset) do
    {attributes, _spaces} = split_attributes_and_spaces(attr_nodes)
    {[{tag, Enum.reverse(attributes), nodes}], context}
  end

  defp match_tags(_rest, [closing, [[opening | _] | _]], _context, _line, _offset),
    do: {:error, "closing tag #{inspect(closing)} did not match opening tag #{inspect(opening)}"}

  defp match_tags(_rest, [[[opening | _] | _]], _context, _line, _offset),
    do: {:error, "expected closing tag for #{inspect(opening)}"}

  defp interpolation(_rest, ["}}" | nodes], context, _line, _offset),
    do: {[{:interpolation, nodes |> Enum.reverse() |> IO.iodata_to_binary()}], context}

  defp interpolation(_rest, _, _context, _line, _offset),
    do: {:error, "expected closing for interpolation"}

  defp split_attributes_and_spaces(attr_nodes) do
    Enum.reduce(attr_nodes, {[], []}, fn
      {[attr, value], {line, _}}, {attributes, spaces} ->
        {[{attr, value, line} | attributes], spaces}

      space, {attributes, spaces} ->
        {attributes, [space|spaces]}
    end)
  end

  ## Macro node

  text_without_interpolation = utf8_string([not: ?<], min: 1)
  opening_macro_tag = ignore(string("<#")) |> concat(tag) |> ignore(string(">"))
  closing_macro_tag = ignore(string("</#")) |> concat(tag) |> ignore(string(">"))

  macro_node =
    opening_macro_tag
    |> post_traverse(:opening_macro_tag)
    |> repeat_while(choice([string("<"), text_without_interpolation]), :lookahead_macro_tag)
    |> wrap()
    |> optional(closing_macro_tag)
    |> post_traverse(:closing_macro_tag)

  defp opening_macro_tag(_rest, [tag], context, _, _) do
    {[], %{context | macro: tag}}
  end

  defp closing_macro_tag(_, [macro, rest], %{macro: macro} = context, _, _) do
    tag = "#" <> macro
    text = IO.iodata_to_binary(rest)
    {[{tag, [], [text]}], %{context | macro: nil}}
  end

  defp closing_macro_tag(_rest, _nodes, %{macro: macro}, _, _) do
    {:error, "expected closing tag for #{inspect("#" <> macro)}"}
  end

  defp lookahead_macro_tag(rest, %{macro: macro} = context, _, _) do
    size = byte_size(macro)

    case rest do
      <<"</#", macro_match::binary-size(size), ">", _::binary>> when macro_match == macro ->
        {:halt, context}

      _ ->
        {:cont, context}
    end
  end

  @blanks ' \n\r\t\v\b\f\e\d\a'

  defp blank?([]), do: true

  defp blank?([h|t]), do: blank?(h) && blank?(t)

  defp blank?(""), do: true

  defp blank?(char) when char in @blanks, do: true

  defp blank?(<<h, t::binary>>) when h in @blanks, do: blank?(t)

  defp blank?(_), do: false

  defparsec :node,
            [macro_node, regular_node, self_closing_node]
            |> choice()
            |> label("opening HTML tag"),
            inline: true
end
