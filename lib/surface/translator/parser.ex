defmodule Surface.Translator.Parser do
  import NimbleParsec
  alias Surface.Translator.{TagNode, ComponentNode}

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

  # TODO: Find a better way to do this
  defp content_expr("{{") do
    "<%="
  end

  defp content_expr("}}") do
    "%>"
  end

  defp content_expr(expr) do
    expr
  end

  expr1 =
    string("<%")
    |> repeat(lookahead_not(string("%>")) |> utf8_char([]))
    |> string("%>")
    |> reduce({List, :to_string, []})

  expr2 =
    string("{{")
    |> repeat(lookahead_not(string("}}")) |> utf8_char([]))
    |> string("}}")
    |> map(:content_expr)
    |> reduce({List, :to_string, []})

  expr = choice([expr1, expr2])

  boolean =
    choice([
      string("true") |> replace(true),
      string("false") |> replace(false)
    ])

  attribute_expr =
    ignore(string("{{"))
    |> repeat(lookahead_not(string("}}")) |> utf8_char([]))
    |> ignore(string("}}"))
    |> reduce({List, :to_string, []})
    |> tag(:attribute_expr)

  tag_name = ascii_string([?a..?z, ?0..?9, ?A..?Z, ?-, ?., ?_], min: 1)

  attr_name = ascii_string([?a..?z, ?0..?9, ?A..?Z, ?-, ?., ?_, ?:], min: 1)

  text =
    utf8_char(not: ?<)
    |> repeat(
      lookahead_not(
        choice([
          ignore(string("<")),
          ignore(string("<%")),
          ignore(string("{{"))
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
        attribute_expr,
        utf8_char([])
      ])
    )
    |> ignore(ascii_char([?"]))
    |> wrap()

  attribute =
    attr_name
    |> concat(whitespace)
    |> optional(
      choice([
        ignore(string("=")) |> concat(attribute_expr),
        ignore(string("=")) |> concat(attribute_value),
        ignore(string("=")) |> concat(integer(min: 1)),
        ignore(string("=")) |> concat(boolean)
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
      |> concat(children)
      |> concat(closing_tag)
    ])
    |> post_traverse(:validate_node)

  defparsecp(
    :parse_children,
    whitespace_no_ignore
    |> repeat(
      choice([
        tag,
        comment,
        expr,
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

        children = (args[:child] || [])

        case tag do
          <<first, _::binary>> when first in ?A..?Z ->
            {[%ComponentNode{name: tag, attributes: attributes, children: children, line: line}], context}
          _ ->
            {[%TagNode{name: tag, attributes: attributes, children: children, line: line}], context}
        end

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
end
