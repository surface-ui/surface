defmodule Surface.Formatter.Phases.Render do
  @moduledoc """
             Render the formatted Surface code after it has run through the other
             transforming phases.
             """ && false

  @behaviour Surface.Formatter.Phase
  alias Surface.Formatter

  def run(nodes, opts) do
    nodes
    |> Enum.map(&render_node(&1, opts))
    |> List.flatten()
    |> Enum.join()
  end

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @default_line_length 98

  @newline_not_followed_by_newline ~r/\n(?!\n)/

  @doc """
  Given a `t:Surface.Formatter.formatter_node/0` node, render it to a string
  for writing back into a file.
  """
  @spec render_node(Formatter.formatter_node(), list(Formatter.option())) :: String.t() | nil
  def render_node(segment, opts)

  def render_node({:expr, expression, _meta}, opts) do
    case Regex.run(~r/^\s*#(.*)$/, expression) do
      nil ->
        formatted =
          expression
          |> String.trim()
          |> Code.format_string!(opts)
          |> to_string()
          # handle scenario where expression contains string(s) with newlines;
          # in order to ensure the formatter is idempotent (always emits
          # the same output when run more than once), we dedent newlines
          # in strings because multi-line strings are later indented
          |> dedent_strings_with_newlines(expression, opts)

        String.replace(
          "{#{formatted}}",
          @newline_not_followed_by_newline,
          "\n#{String.duplicate(@tab, opts[:indent])}"
        )

      [_, comment] ->
        # expression is a one-line Elixir comment; convert to a "Surface comment"
        "{!-- #{String.trim(comment)} --}"
    end
  end

  def render_node(:indent, opts) do
    if opts[:indent] >= 0 do
      String.duplicate(@tab, opts[:indent])
    else
      ""
    end
  end

  def render_node(:newline, _opts) do
    # There are multiple newlines in a row; don't add spaces
    # if there aren't going to be other characters after it
    "\n"
  end

  def render_node(:space, _opts) do
    " "
  end

  def render_node({:comment, comment, %{visibility: :public}}, _opts) do
    if String.contains?(comment, "\n") do
      comment
    else
      contents =
        comment
        |> String.replace(~r/^<!--/, "")
        |> String.replace(~r/-->$/, "")
        |> String.trim()

      "<!-- #{contents} -->"
    end
  end

  def render_node({:comment, comment, %{visibility: :private}}, _opts) do
    if String.contains?(comment, "\n") do
      comment
    else
      contents =
        comment
        |> String.replace(~r/^{!--/, "")
        |> String.replace(~r/--}$/, "")
        |> String.trim()

      "{!-- #{contents} --}"
    end
  end

  def render_node(:indent_one_less, opts) do
    # Dedent once; this is before a closing tag, so it should be dedented from children
    render_node(:indent, indent: opts[:indent] - 1)
  end

  def render_node(html, _opts) when is_binary(html) do
    html
  end

  # default block does not get rendered `{#default}`; just children are rendered
  def render_node({:block, :default, [], children, _meta}, opts) do
    next_opts = Keyword.update(opts, :indent, 0, &(&1 + 1))
    Enum.map(children, &render_node(&1, next_opts))
  end

  def render_node({:block, name, expr, children, _meta}, opts) do
    main_block_element = name in ["if", "unless", "for", "case"]

    expr =
      case expr do
        [attr] ->
          attr
          |> render_attribute([])
          |> case do
            {:do_not_indent_newlines, string} ->
              string

            string ->
              string
              |> String.slice(1..-2//1)
              |> String.trim()
          end

        [] ->
          nil
      end

    opening =
      "{##{name}#{if expr, do: " "}#{expr}}"
      |> String.replace(
        @newline_not_followed_by_newline,
        "\n" <> String.duplicate(@tab, opts[:indent] + 1)
      )

    next_indent =
      case children do
        [{:block, _, _, _, _} | _] -> 0
        _ -> 1
      end

    next_opts = Keyword.update(opts, :indent, 0, &(&1 + next_indent))
    rendered_children = Enum.map(children, &render_node(&1, next_opts))

    "#{opening}#{rendered_children}#{if main_block_element do
      "{/#{name}}"
    end}"
  end

  def render_node({tag, attributes, [], _meta}, opts) do
    render_opening_tag(
      tag,
      attributes,
      Keyword.put(opts, :self_closing, true)
    )
  end

  def render_node({tag, attributes, children, _meta}, opts) do
    rendered_children =
      if Formatter.render_contents_verbatim?(tag) do
        Enum.map(children, fn
          html when is_binary(html) ->
            # Render out string portions of <pre>/<code>/<#MacroComponent> children
            # verbatim instead of trimming them.
            html

          child ->
            render_node(child, indent: 0)
        end)
      else
        next_opts = Keyword.update(opts, :indent, 0, &(&1 + 1))

        Enum.map(children, &render_node(&1, next_opts))
      end

    "#{render_opening_tag(tag, attributes, opts)}#{rendered_children}</#{tag}>"
  end

  defp render_opening_tag(tag, [] = _attributes, opts) do
    if opts[:self_closing] && not is_void_element?(tag) do
      "<#{tag} />"
    else
      "<#{tag}>"
    end
  end

  defp render_opening_tag(tag, attributes, opts) do
    max_line_length = opts[:line_length] || @default_line_length
    self_closing = Keyword.get(opts, :self_closing, false)
    indentation = String.duplicate(@tab, opts[:indent])

    rendered_attributes =
      Enum.map(
        attributes,
        &render_attribute(&1, Keyword.put(opts, :attributes, attributes))
      )

    attribute_strings =
      Enum.map(rendered_attributes, fn
        {:do_not_indent_newlines, attr} -> attr
        attr -> attr
      end)

    # calculate length of the entire opening tag if fit on a single line
    total_attr_lengths =
      attribute_strings
      |> Enum.map(&String.length/1)
      |> Enum.sum()

    # consider tag name, space before each attribute, < and > (and ` /` for self-closing tags)
    length_on_same_line =
      total_attr_lengths + String.length(tag) + length(attributes) +
        if self_closing do
          4
        else
          2
        end

    put_attributes_on_separate_lines =
      if length(attributes) > 1 do
        length_on_same_line > max_line_length or
          Enum.any?(attribute_strings, &String.contains?(&1, "\n"))
      else
        false
      end

    if put_attributes_on_separate_lines do
      attr_indentation = String.duplicate(@tab, opts[:indent] + 1)

      indented_attributes =
        Enum.map(rendered_attributes, fn
          {:do_not_indent_newlines, attr} ->
            "#{attr_indentation}#{attr}"

          attr ->
            # This is pretty hacky, but it's an attempt to get things like
            #   class={
            #     "foo",
            #     @bar,
            #     baz: true
            #   }
            # to look right
            with_newlines_indented =
              String.replace(attr, @newline_not_followed_by_newline, "\n#{attr_indentation}")

            "#{attr_indentation}#{with_newlines_indented}"
        end)

      [
        "<#{tag}",
        indented_attributes,
        "#{indentation}#{if self_closing do
          "/"
        end}>"
      ]
      |> List.flatten()
      |> Enum.join("\n")
    else
      # We're not splitting attributes onto their own newlines,
      # but it's possible that an attribute has a newline in it
      # (for interpolated maps/lists) so ensure those lines are indented.
      # We're rebuilding the tag from scratch so we can respect
      # :do_not_indent_newlines attributes.
      attr_indentation = String.duplicate(@tab, opts[:indent])

      attributes =
        case rendered_attributes do
          [] ->
            ""

          _ ->
            joined_attributes =
              rendered_attributes
              |> Enum.map(fn
                {:do_not_indent_newlines, attr} ->
                  attr

                attr ->
                  String.replace(attr, @newline_not_followed_by_newline, "\n#{attr_indentation}")
              end)
              |> Enum.join(" ")

            # Prefix attributes string with a space (for after tag name)
            " " <> joined_attributes
        end

      "<#{tag}#{attributes}#{if self_closing and not is_void_element?(tag) do
        " /"
      end}>"
    end
  end

  @type render_attribute_option :: {:attributes, [Surface.Formatter.attribute()]}

  @spec render_attribute({String.t(), term, map}, [render_attribute_option]) ::
          String.t() | {:do_not_indent_newlines, String.t()}
  defp render_attribute({name, value, _meta}, _opts) when is_binary(value) do
    # This is a string, and it might contain newlines. By returning
    # `{:do_not_indent_newlines, formatted}` we instruct `render_node/1`
    # to leave newlines alone instead of adding extra tabs at the
    # beginning of the line.
    #
    # Before this behavior, the extra lines in the `bar` attribute below
    # would be further indented each time the formatter was run.
    #
    # <Component foo=false bar="a
    #   b
    #   c"
    # />
    rendered =
      if name == :root do
        inspect(value)
      else
        "#{name}=\"#{String.trim(value)}\""
      end

    {:do_not_indent_newlines, rendered}
  end

  # Only for :hook directive return itself since isn't an boolean directive
  # and could be defined without value and assuming the `"default"`.
  defp render_attribute({name, true, _meta}, _opts) when name in [":hook", ":debug"], do: "#{name}"

  # For `true` boolean attributes, simply including the name of the attribute
  # without `=true` is shorthand for `=true`.
  defp render_attribute({":" <> _ = name, true, _meta}, _opts),
    do: "#{name}={true}"

  defp render_attribute({name, true, _meta}, _opts),
    do: "#{name}"

  defp render_attribute({name, false, _meta}, _opts),
    do: "#{name}={false}"

  defp render_attribute({name, value, _meta}, _opts) when is_integer(value),
    do: "#{name}={#{Code.format_string!("#{value}")}}"

  defp render_attribute({_name, {:attribute_expr, expression, %{tagged_expr?: true}}, _}, _opts) do
    "{=#{expression}}"
  end

  defp render_attribute({name, {:attribute_expr, expression, _expr_meta}, _meta}, opts)
       when name in [":attrs", ":props"] do
    "{...#{format_attribute_expression(expression, opts)}}"
  end

  defp render_attribute({:root, {:attribute_expr, expression, _expr_meta}, _meta}, opts) do
    case Regex.split(~r[^\s*\.\.\.], expression) do
      [_, expr] -> "{...#{format_attribute_expression(expr, opts)}}"
      [expr] -> "{#{format_attribute_expression(expr, opts)}}"
    end
  end

  defp render_attribute({name, {:attribute_expr, expression, _expr_meta}, meta}, opts) do
    case quoted_wrapped_expression(expression) do
      [literal] when is_boolean(literal) or is_binary(literal) ->
        # The expression is a literal value in Surface brackets, e.g. {"foo"} or {true},
        # that can exclude the brackets, so render it without the brackets
        render_attribute({name, literal, meta}, opts)

      _ ->
        "#{name}={#{format_attribute_expression(expression, opts)}}"
    end
  end

  @spec quoted_strings_with_newlines(Macro.t() | String.t()) :: [String.t()]
  # given an attribute expression, return a list of strings that have newlines in them
  defp quoted_strings_with_newlines(attribute_expression) when is_binary(attribute_expression) do
    attribute_expression
    |> quoted_wrapped_expression()
    |> quoted_strings_with_newlines()
  end

  defp quoted_strings_with_newlines(nodes) when is_list(nodes) do
    Enum.flat_map(nodes, fn
      string when is_binary(string) ->
        if String.contains?(string, "\n") do
          [string]
        else
          []
        end

      [{:do, string}] when is_binary(string) ->
        if String.contains?(string, "\n") do
          [string]
        else
          []
        end

      {operation, _, nodes} when is_atom(operation) and is_list(nodes) ->
        quoted_strings_with_newlines(nodes)

      [{:do, node_or_nodes}] ->
        quoted_strings_with_newlines(node_or_nodes)

      nodes when is_list(nodes) ->
        quoted_strings_with_newlines(nodes)

      _ ->
        []
    end)
    |> List.flatten()
  end

  defp quoted_strings_with_newlines(node) do
    quoted_strings_with_newlines([node])
  end

  defp is_keyword_item_with_interpolated_key?(item) do
    case item do
      {{{:., _, [:erlang, :binary_to_atom]}, _, [_, :utf8]}, _} -> true
      _ -> false
    end
  end

  defp is_void_element?(tag) do
    tag in ~w(area base br col command embed hr img input keygen link meta param source track wbr)
  end

  defp quoted_wrapped_expression(expression) when is_binary(expression) do
    # Wrap it in square brackets (and then remove after formatting) to support
    # Surface sugar like this: `{foo: "bar"}` (equivalent to `{[foo: "bar"]}}`
    Code.string_to_quoted!("[#{expression}]")
  rescue
    _exception ->
      # With some expressions such as function calls without parentheses
      # (e.g. `Enum.map @items, & &1.foo`) wrapping in square brackets will
      # emit invalid syntax, so we must catch that here
      Code.string_to_quoted!(expression)
  end

  @spec format_attribute_expression(String.t(), [render_attribute_option]) :: String.t()
  defp format_attribute_expression(expression, opts) when is_binary(expression) do
    formatted =
      if has_invisible_brackets?(expression) do
        # handle keyword lists, which will be stripped of the outer brackets per surface syntax sugar
        "[#{expression}]"
        |> Code.format_string!(locals_without_parens: [...: 1])
        |> Enum.slice(1..-2//1)
        |> to_string()
      else
        expression
        |> Code.format_string!(locals_without_parens: [...: 1])
        |> to_string()
      end

    if length(Keyword.get(opts, :attributes, [])) > 1 do
      # handle scenario where list contains string(s) with newlines;
      # in order to ensure the formatter is idempotent (always emits
      # the same output when run more than once), we dedent newlines
      # in strings because multi-line attributes are later indented
      opts = Keyword.update(opts, :indent, 0, &(&1 + 1))
      dedent_strings_with_newlines(formatted, expression, opts)
    else
      formatted
    end
  end

  @spec has_invisible_brackets?(Macro.t() | String.t()) :: boolean
  defp has_invisible_brackets?(expression) when is_binary(expression) do
    expression
    |> quoted_wrapped_expression()
    |> has_invisible_brackets?()
  end

  defp has_invisible_brackets?(quoted_wrapped_expression) do
    # This is a somewhat hacky way of checking if the contents are something like:
    #
    #   foo={"bar", @baz, :qux}
    #   foo={"bar", baz: true}
    #
    # which is valid Surface syntax; an outer list wrapping the entire expression is implied.
    Keyword.keyword?(quoted_wrapped_expression) or
      (is_list(quoted_wrapped_expression) and length(quoted_wrapped_expression) > 1) or
      (is_list(quoted_wrapped_expression) and
         Enum.any?(quoted_wrapped_expression, &is_keyword_item_with_interpolated_key?/1))
  end

  defp dedent_strings_with_newlines(formatted, original_expression, opts) do
    original_expression
    |> quoted_strings_with_newlines()
    |> Enum.uniq()
    |> Enum.reduce(formatted, fn string_with_newlines, formatted ->
      dedented =
        String.replace(
          string_with_newlines,
          "\n#{String.duplicate(@tab, opts[:indent])}",
          "\n"
        )

      String.replace(formatted, string_with_newlines, dedented)
    end)
  end
end
