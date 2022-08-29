defmodule Surface.Formatter.Phases.TagWhitespace do
  @moduledoc """
             Inspects all text nodes and "tags" leading and trailing whitespace
             by converting it into a `:space` atom or a list of `:newline` atoms.

             This is the first phase of formatting, and all other phases depend on it.
             """ && false

  @behaviour Surface.Formatter.Phase
  alias Surface.Formatter

  def run(nodes, _opts) do
    Enum.flat_map(nodes, &tag_whitespace/1)
  end

  @doc """
  This function takes a node provided by `Surface.Compiler.Parser.parse`
  and converts the leading/trailing whitespace into `t:Surface.Formatter.whitespace/0` nodes.
  """
  @spec tag_whitespace(Formatter.surface_node()) :: [
          Formatter.surface_node() | :newline | :space
        ]
  def tag_whitespace(text) when is_binary(text) do
    # This is a string/text node; analyze and tag the leading and trailing whitespace

    if String.trim(text) == "" do
      # This is a whitespace-only node; tag the whitespace
      tag_whitespace_string(text)
    else
      # This text contains more than whitespace; analyze and tag the leading
      # and trailing whitespace separately.
      leading_whitespace =
        ~r/^\s+/
        |> single_match!(text)
        |> tag_whitespace_string()

      trailing_whitespace =
        ~r/\s+$/
        |> single_match!(text)
        |> tag_whitespace_string()

      # Get each line of the text node, with whitespace trimmed so we can fix indentation
      lines =
        text
        |> String.trim()
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.intersperse(:newline)
        |> Enum.reject(&(&1 == ""))

      leading_whitespace ++ lines ++ trailing_whitespace
    end
  end

  def tag_whitespace({tag, attributes, children, meta}) do
    # This is an HTML element or Surface component

    children =
      if Formatter.render_contents_verbatim?(tag) do
        # Don't tag the contents of this element; it's in a protected class
        # of elements in which the contents are not supposed to be touched
        # (such as <pre>).
        #
        # Note that since we're not tagging the whitespace (i.e. converting
        # sections of the string to :newline and :space atoms), this means
        # we can adjust the whitespace tags later and we're guaranteed not
        # to accidentally modify the contents of these "render verbatim" tags.
        children
      else
        # Recurse into tag_whitespace for all of the children of this element/component
        # so that they get their whitespace tagged as well
        run(children, [])
      end

    [{tag, attributes, children, meta}]
  end

  def tag_whitespace({:block, name, expr, body, meta}) when is_list(body) do
    [{:block, name, expr, run(body, []), meta}]
  end

  def tag_whitespace({:expr, _, _} = interpolation), do: [interpolation]
  def tag_whitespace({:comment, _, _} = comment), do: [comment]

  # Tag a string that only has whitespace, returning [:space] or a list of `:newline`
  @spec tag_whitespace_string(String.t() | nil) :: list(:space | :newline)
  defp tag_whitespace_string(nil), do: []

  defp tag_whitespace_string(text) when is_binary(text) do
    # This span of text is _only_ whitespace
    newlines =
      text
      |> String.graphemes()
      |> Enum.count(&(&1 == "\n"))

    if newlines > 0 do
      List.duplicate(:newline, newlines)
    else
      [:space]
    end
  end

  defp single_match!(regex, string) do
    case Regex.run(regex, string) do
      [match] -> match
      nil -> nil
    end
  end
end
