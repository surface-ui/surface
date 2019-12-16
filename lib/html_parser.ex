defmodule HTMLParser do
  import NimbleParsec

  # TODO: attributes
  # TODO: self-closing tags
  # TODO: use line+line_offset+byte_offset in parse/1 for error reporting

  @doc """
  Parses a surface HTML document.
  """
  def parse(content) do
    case node(content, context: [macro: nil]) do
      {:ok, tree, "", %{macro: nil}, _, _} ->
        {:ok, tree}

      {:ok, _, rest, %{macro: nil}, _, _} ->
        {:error, "expected end of string, found: #{inspect(rest)}"}

      {:error, message, _rest, _context, _line_offset, _byte_offset} ->
        {:error, message}
    end
  end

  ## Common helpers

  tag =
    ascii_char([?a..?z, ?A..?Z])
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?-, ?., ?_], min: 0)
    |> reduce({List, :to_string, []})

  ## Self-closing node

  self_closing_node =
    ignore(string("<"))
    |> concat(tag)
    |> ignore(string("/>"))
    |> post_traverse(:self_closing_tags)

  defp self_closing_tags(_rest, [tag], context, _line, _offset), do: {[{tag, [], []}], context}

  ## Regular node

  interpolation =
    ignore(string("{{"))
    |> repeat(lookahead_not(string("}}")) |> utf8_char([]))
    |> optional(string("}}"))
    |> post_traverse(:interpolation)

  text_with_interpolation = utf8_string([not: ?<, not: ?{], min: 1)

  opening_tag = ignore(string("<")) |> concat(tag) |> ignore(string(">"))
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

  defp match_tags(_rest, [tag, [tag | nodes]], context, _line, _offset),
    do: {[{tag, [], nodes}], context}

  defp match_tags(_rest, [closing, [opening | _]], _context, _line, _offset),
    do: {:error, "closing tag #{inspect(closing)} did not match opening tag #{inspect(opening)}"}

  defp match_tags(_rest, [[opening | _]], _context, _line, _offset),
    do: {:error, "expected closing tag for #{inspect(opening)}"}

  defp interpolation(_rest, ["}}" | nodes], context, _line, _offset),
    do: {[{:interpolation, nodes |> Enum.reverse() |> IO.iodata_to_binary()}], context}

  defp interpolation(_rest, _, _context, _line, _offset),
    do: {:error, "expected closing for interpolation"}

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

  defparsec :node,
            [macro_node, regular_node, self_closing_node]
            |> choice()
            |> label("opening HTML tag"),
            inline: true
end
