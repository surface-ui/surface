defmodule Surface.Compiler.Tokenizer do
  @moduledoc false
  @space_chars ~c"\n\r\t\f\s"
  @name_stop_chars @space_chars ++ ~c">/="
  @unquoted_value_invalid_chars ~c"\"'=<`"
  @unquoted_value_stop_chars @space_chars ++ ~c">"
  @block_name_stop_chars @space_chars ++ ~c"}"
  @markers ["=", "...", "$", "^", ~S(~")]

  @ignored_body_tags ["style", "script"]

  @void_elements [
    "area",
    "base",
    "br",
    "col",
    "command",
    "embed",
    "hr",
    "img",
    "input",
    "keygen",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr"
  ]

  @type metadata :: %{
          line: integer(),
          column: integer(),
          line_end: integer(),
          column_end: integer(),
          file: binary()
        }

  @type text :: {:text, value :: binary()}

  @type comment_metadata :: metadata() | %{visibility: :public | :private}
  @type comment :: {:comment, value :: binary(), comment_metadata()}

  @type block_metadata :: metadata()
  @type block_name :: binary() | :default
  @type block_open ::
          {:block_open, block_name, expression :: nil | binary(), block_metadata()}
  @type block_close :: {:block_close, block_name, metadata()}

  @type expression_metadata :: {:expr, value :: binary(), metadata()}
  @type expression :: {:expr, value :: binary(), metadata()}

  @type attribute_value :: {:string, value :: binary() | nil, metadata()} | expression()
  @type attribute_name :: binary() | :root
  @type attribute_metadata :: metadata()
  @type attribute :: {attribute_name(), attribute_value(), metadata()}

  @type tag_metadata ::
          metadata()
          | %{
              void_tag?: boolean(),
              macro?: boolean(),
              ignored_body?: boolean(),
              self_close: boolean(),
              node_line_end: integer(),
              node_column_end: integer()
            }
  @type tag_name :: binary()
  @type tag_open :: {:tag_open, name :: binary(), list(attribute()), tag_metadata()}
  @type tag_close :: {:tag_close, name :: binary(), metadata()}

  @type token :: text() | comment() | block_open() | block_close() | tag_open() | tag_close()

  alias Surface.Compiler.ParseError

  @spec tokenize!(binary(), keyword()) :: list(token())
  def tokenize!(text, opts \\ []) do
    file = Keyword.get(opts, :file, "nofile")
    line = Keyword.get(opts, :line, 1)
    column = Keyword.get(opts, :column, 1)
    indentation = Keyword.get(opts, :indentation, 0)

    state = %{file: file, column_offset: indentation + 1, braces: []}

    handle_text(text, line, column, [], [], state)
  end

  ## handle_text

  defp handle_text("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_text("\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_text("<!doctype" <> rest, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 9, ["<!doctype" | buffer], acc, state)
  end

  defp handle_text("<!DOCTYPE" <> rest, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 9, ["<!DOCTYPE" | buffer], acc, state)
  end

  defp handle_text("<!--" <> rest, line, column, buffer, acc, state) do
    acc = text_to_acc(buffer, acc)

    {new_rest, new_line, new_column, new_buffer} = handle_comment(rest, line, column + 4, ["<!--"], state)

    comment = buffer_to_string(new_buffer)

    meta = %{
      line: line,
      column: column,
      new_line: new_line,
      new_column: new_column,
      file: state.file,
      visibility: :public
    }

    handle_text(new_rest, new_line, new_column, [], [{:comment, comment, meta} | acc], state)
  end

  defp handle_text("{!--" <> rest, line, column, buffer, acc, state) do
    acc = text_to_acc(buffer, acc)

    {new_rest, new_line, new_column, new_buffer} = handle_private_comment(rest, line, column + 4, ["{!--"], state)

    comment = buffer_to_string(new_buffer)

    meta = %{
      line: line,
      column: column,
      new_line: new_line,
      new_column: new_column,
      file: state.file,
      visibility: :private
    }

    handle_text(new_rest, new_line, new_column, [], [{:comment, comment, meta} | acc], state)
  end

  defp handle_text("{#" <> rest, line, column, buffer, acc, state) do
    handle_block_open(rest, line, column + 2, text_to_acc(buffer, acc), state)
  end

  defp handle_text("{/" <> rest, line, column, buffer, acc, state) do
    handle_block_close(rest, line, column + 2, text_to_acc(buffer, acc), state)
  end

  defp handle_text("{" <> rest, line, column, buffer, acc, state) do
    {expr, new_line, new_column, rest} = handle_expression(rest, line, column + 1, state)
    acc = [expr | text_to_acc(buffer, acc)]
    handle_text(rest, new_line, new_column, [], acc, state)
  end

  defp handle_text("</" <> rest, line, column, buffer, acc, state) do
    handle_tag_close(rest, line, column + 2, text_to_acc(buffer, acc), state)
  end

  defp handle_text("<" <> rest, line, column, buffer, acc, state) do
    handle_tag_open(rest, line, column + 1, text_to_acc(buffer, acc), state)
  end

  defp handle_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_text(<<>>, _line, _column, buffer, acc, _state) do
    ok(text_to_acc(buffer, acc))
  end

  ## handle_block_open

  defp handle_block_open(text, line, column, acc, state) do
    case handle_block_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{line: line, column: column, line_end: line, column_end: new_column, file: state.file}

        {new_rest, new_line, new_column} = ignore_spaces(rest, line, new_column, state)
        acc = [{:block_open, name, nil, meta} | acc]
        handle_block_open_expr(new_rest, new_line, new_column, acc, state)

      {:error, message} ->
        raise parse_error(message, line, column, state)
    end
  end

  ## handle_block_close

  defp handle_block_close(text, line, column, acc, state) do
    case handle_block_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{line: line, column: column, line_end: line, column_end: new_column, file: state.file}

        acc = [{:block_close, name, meta} | acc]
        handle_block_close_end(rest, line, new_column, acc, state)

      {:error, message} ->
        raise parse_error(message, line, column, state)
    end
  end

  defp handle_block_close_end("}" <> rest, line, column, acc, state) do
    handle_text(rest, line, column + 1, [], acc, state)
  end

  defp handle_block_close_end(_text, line, column, _acc, state) do
    raise parse_error("expected closing `}`", line, column, state)
  end

  ## handle_block_name

  defp handle_block_name(<<c::utf8, _rest::binary>>, _column, []) when c in @block_name_stop_chars do
    {:error, "expected block name"}
  end

  defp handle_block_name(<<c::utf8, _rest::binary>> = text, column, buffer) when c in @block_name_stop_chars do
    {:ok, buffer_to_string(buffer), column, text}
  end

  defp handle_block_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_block_name(rest, column + 1, [<<c::utf8>> | buffer])
  end

  ## handle_block_open_expr

  defp handle_block_open_expr(text, line, column, acc, state) do
    case handle_expression_value(text, line, column, state) do
      {:ok, {:expr, value, expr_meta}, new_line, new_column, rest, state} ->
        expr = if value == "", do: nil, else: {:expr, value, expr_meta}

        [{:block_open, name, nil, meta} | acc] = acc
        acc = [{:block_open, name, expr, meta} | acc]

        handle_text(rest, new_line, new_column, [], acc, state)

      {:error, :expected_closing_brace, error_line, error_column} ->
        [{:block_open, name, nil, %{line: line, column: column}} | _] = acc

        message = """
        expected closing `}` for opening block expression `{##{name}` beginning at \
        line: #{line}, column: #{column - 1}\
        """

        raise parse_error(message, error_line, error_column, state)

      {:error, type, line, column} ->
        raise parse_error("parser error: #{inspect(type)}", line, column, state)
    end
  end

  ## handle_doctype

  defp handle_doctype(<<?>, rest::binary>>, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 1, [?> | buffer], acc, state)
  end

  defp handle_doctype("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_doctype(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_doctype("\n" <> rest, line, _column, buffer, acc, state) do
    handle_doctype(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_doctype(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_doctype(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  ## handle_comment

  defp handle_comment("\r\n" <> rest, line, _column, buffer, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\r\n" | buffer], state)
  end

  defp handle_comment("\n" <> rest, line, _column, buffer, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\n" | buffer], state)
  end

  defp handle_comment("-->" <> rest, line, column, buffer, _state) do
    {rest, line, column + 3, ["-->" | buffer]}
  end

  defp handle_comment(<<c::utf8, rest::binary>>, line, column, buffer, state) do
    handle_comment(rest, line, column + 1, [<<c::utf8>> | buffer], state)
  end

  defp handle_comment(<<>>, line, column, _buffer, state) do
    raise parse_error("expected closing `-->` for comment", line, column, state)
  end

  ## handle_private_comment

  defp handle_private_comment("\r\n" <> rest, line, _column, buffer, state) do
    handle_private_comment(rest, line + 1, state.column_offset, ["\r\n" | buffer], state)
  end

  defp handle_private_comment("\n" <> rest, line, _column, buffer, state) do
    handle_private_comment(rest, line + 1, state.column_offset, ["\n" | buffer], state)
  end

  defp handle_private_comment("--}" <> rest, line, column, buffer, _state) do
    {rest, line, column + 3, ["--}" | buffer]}
  end

  defp handle_private_comment(<<c::utf8, rest::binary>>, line, column, buffer, state) do
    handle_private_comment(rest, line, column + 1, [<<c::utf8>> | buffer], state)
  end

  defp handle_private_comment(<<>>, line, column, _buffer, state) do
    raise parse_error("expected closing `--}` for comment", line, column, state)
  end

  ## handle_macro_body

  defp handle_macro_body("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_macro_body(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_macro_body("\n" <> rest, line, _column, buffer, acc, state) do
    handle_macro_body(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_macro_body("</#" <> text, line, column, buffer, acc, state) do
    handle_maybe_macro_close_tag("#" <> text, line, column + 2, buffer, acc, state)
  end

  defp handle_macro_body(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_macro_body(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_macro_body(<<>>, _line, _column, buffer, acc, _state) do
    ok(text_to_acc(buffer, acc))
  end

  ## handle_maybe_macro_close_tag

  defp handle_maybe_macro_close_tag(text, line, column, buffer, [{:tag_open, tag_name, _, _} | _] = acc, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, rest} when name == tag_name ->
        meta = %{line: line, column: column, line_end: line, column_end: new_column, file: state.file}

        acc = text_to_acc(buffer, acc)
        acc = [{:tag_close, name, meta} | acc]

        handle_tag_close_end(rest, line, new_column, acc, state)

      _ ->
        handle_macro_body(text, line, column, ["</" | buffer], acc, state)
    end
  end

  ## handle_ignored_body

  defp handle_ignored_body("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_ignored_body(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_ignored_body("\n" <> rest, line, _column, buffer, acc, state) do
    handle_ignored_body(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_ignored_body("</" <> rest, line, column, buffer, acc, state) do
    acc = text_to_acc(buffer, acc)
    handle_tag_close(rest, line, column + 2, acc, state)
  end

  defp handle_ignored_body(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_ignored_body(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_ignored_body(<<>>, _line, _column, buffer, acc, _state) do
    ok(text_to_acc(buffer, acc))
  end

  ## handle_tag_open

  defp handle_tag_open(text, line, column, acc, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{
          line: line,
          column: column,
          line_end: line,
          column_end: new_column,
          file: state.file,
          self_close: false,
          void_tag?: name in @void_elements,
          macro?: macro_tag?(name),
          ignored_body?: name in @ignored_body_tags
        }

        acc = [{:tag_open, name, [], meta} | acc]
        handle_maybe_tag_open_end(rest, line, new_column, acc, state)

      {:error, message} ->
        raise parse_error(message, line, column, state)
    end
  end

  ## handle_tag_close

  defp handle_tag_close(text, line, column, acc, state) do
    case handle_tag_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{line: line, column: column, line_end: line, column_end: new_column, file: state.file}

        acc = [{:tag_close, name, meta} | acc]
        handle_tag_close_end(rest, line, new_column, acc, state)

      {:error, message} ->
        raise parse_error(message, line, column, state)
    end
  end

  defp handle_tag_close_end(">" <> rest, line, column, acc, state) do
    handle_text(rest, line, column + 1, [], acc, state)
  end

  defp handle_tag_close_end(_text, line, column, _acc, state) do
    raise parse_error("expected closing `>`", line, column, state)
  end

  ## handle_tag_name

  defp handle_tag_name(<<c::utf8, _rest::binary>>, _column, _buffer = []) when c in @name_stop_chars do
    {:error, "expected tag name"}
  end

  defp handle_tag_name(<<c::utf8, _rest::binary>> = text, column, buffer) when c in @name_stop_chars do
    {:ok, buffer_to_string(buffer), column, text}
  end

  defp handle_tag_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_tag_name(rest, column + 1, [<<c::utf8>> | buffer])
  end

  ## handle_maybe_tag_open_end

  defp handle_maybe_tag_open_end("\r\n" <> rest, line, _column, acc, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_tag_open_end("\n" <> rest, line, _column, acc, state) do
    handle_maybe_tag_open_end(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_tag_open_end(<<c::utf8, rest::binary>>, line, column, acc, state) when c in @space_chars do
    handle_maybe_tag_open_end(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_tag_open_end("/>" <> rest, line, column, acc, state) do
    acc =
      acc
      |> reverse_attrs()
      |> update_meta(self_close: true, node_line_end: line, node_column_end: column)

    handle_text(rest, line, column + 2, [], acc, state)
  end

  defp handle_maybe_tag_open_end(
         ">" <> rest,
         line,
         column,
         [{:tag_open, _name, _, %{macro?: true}} | _] = acc,
         state
       ) do
    acc =
      acc
      |> reverse_attrs()
      |> update_meta(node_line_end: line, node_column_end: column)

    handle_macro_body(rest, line, column + 1, [], acc, state)
  end

  defp handle_maybe_tag_open_end(
         ">" <> rest,
         line,
         column,
         [{:tag_open, _name, _, %{ignored_body?: true}} | _] = acc,
         state
       ) do
    acc =
      acc
      |> reverse_attrs()
      |> update_meta(node_line_end: line, node_column_end: column)

    handle_ignored_body(rest, line, column + 1, [], acc, state)
  end

  defp handle_maybe_tag_open_end(">" <> rest, line, column, acc, state) do
    acc =
      acc
      |> reverse_attrs()
      |> update_meta(node_line_end: line, node_column_end: column)

    handle_text(rest, line, column + 1, [], acc, state)
  end

  defp handle_maybe_tag_open_end("{" <> rest, line, column, acc, state) do
    {expr, new_line, new_column, rest} = handle_expression(rest, line, column + 1, state)

    meta = %{line: line, column: column, line_end: new_line, column_end: new_column, file: state.file}

    acc = put_attr(acc, :root, expr, meta)
    handle_maybe_tag_open_end(rest, new_line, new_column, acc, state)
  end

  defp handle_maybe_tag_open_end(<<>>, line, column, _acc, state) do
    raise parse_error("expected closing `>` or `/>`", line, column, state)
  end

  defp handle_maybe_tag_open_end(text, line, column, acc, state) do
    handle_attribute(text, line, column, acc, state)
  end

  ## handle_attribute

  defp handle_attribute(text, line, column, acc, state) do
    case handle_attr_name(text, column, []) do
      {:ok, name, new_column, rest} ->
        meta = %{line: line, column: column, line_end: line, column_end: new_column, file: state.file}

        acc = put_attr(acc, name, nil, meta)
        handle_maybe_attr_value(rest, line, new_column, acc, state)

      {:error, message} ->
        raise parse_error(message, line, column, state)
    end
  end

  ## handle_attr_name
  defp handle_attr_name(<<"/", _rest::binary>>, _column, []) do
    {:error, "unexpected closing tag delimiter `/`"}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>>, _column, []) when c in @name_stop_chars do
    {:error, "expected attribute name, got: `#{<<c>>}`"}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>> = text, column, buffer) when c in @name_stop_chars do
    {:ok, buffer_to_string(buffer), column, text}
  end

  defp handle_attr_name(<<c::utf8, rest::binary>>, column, buffer) do
    handle_attr_name(rest, column + 1, [<<c::utf8>> | buffer])
  end

  ## handle_maybe_attr_value

  defp handle_maybe_attr_value("\r\n" <> rest, line, _column, acc, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_attr_value("\n" <> rest, line, _column, acc, state) do
    handle_maybe_attr_value(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_maybe_attr_value(<<c::utf8, rest::binary>>, line, column, acc, state) when c in @space_chars do
    handle_maybe_attr_value(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_attr_value("=" <> rest, line, column, acc, state) do
    handle_attr_value_begin(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_attr_value(text, line, column, acc, state) do
    handle_maybe_tag_open_end(text, line, column, acc, state)
  end

  ## handle_attr_value_begin

  defp handle_attr_value_begin("\r\n" <> rest, line, _column, acc, state) do
    handle_attr_value_begin(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_attr_value_begin("\n" <> rest, line, _column, acc, state) do
    handle_attr_value_begin(rest, line + 1, state.column_offset, acc, state)
  end

  defp handle_attr_value_begin(<<c::utf8, rest::binary>>, line, column, acc, state) when c in @space_chars do
    handle_attr_value_begin(rest, line, column + 1, acc, state)
  end

  defp handle_attr_value_begin("\"" <> rest, line, column, acc, state) do
    acc = put_attr_value(acc, {:string, nil, %{line: line, column: column + 1, delimiter: ?"}})
    handle_attr_value_double_quote(rest, line, column + 1, [], acc, state)
  end

  defp handle_attr_value_begin("'" <> rest, line, column, acc, state) do
    acc = put_attr_value(acc, {:string, nil, %{line: line, column: column + 1, delimiter: ?'}})
    handle_attr_value_single_quote(rest, line, column + 1, [], acc, state)
  end

  defp handle_attr_value_begin("{" <> rest, line, column, acc, state) do
    {expr, new_line, new_column, rest} = handle_expression(rest, line, column + 1, state)
    acc = put_attr_value(acc, expr)
    handle_maybe_tag_open_end(rest, new_line, new_column, acc, state)
  end

  defp handle_attr_value_begin(<<c::utf8, _::binary>> = text, line, column, acc, state)
       when c not in @name_stop_chars do
    acc = put_attr_value(acc, {:string, nil, %{line: line, column: column, delimiter: nil}})
    handle_attr_value_unquoted(text, line, column, [], acc, state)
  end

  defp handle_attr_value_begin(_text, line, column, _acc, state) do
    raise parse_error("expected attribute value or expression after `=`", line, column, state)
  end

  ## handle_attr_value_double_quote

  defp handle_attr_value_double_quote("\r\n" <> rest, line, _column, buffer, acc, state) do
    column = state.column_offset
    handle_attr_value_double_quote(rest, line + 1, column, ["\r\n" | buffer], acc, state)
  end

  defp handle_attr_value_double_quote("\n" <> rest, line, _column, buffer, acc, state) do
    column = state.column_offset
    handle_attr_value_double_quote(rest, line + 1, column, ["\n" | buffer], acc, state)
  end

  defp handle_attr_value_double_quote("\"" <> rest, line, column, buffer, acc, state) do
    value = buffer_to_string(buffer)

    acc =
      update_attr_value(acc, fn {type, _old_value, meta} ->
        {type, value, Map.merge(meta, %{line_end: line, column_end: column})}
      end)

    handle_maybe_tag_open_end(rest, line, column + 1, acc, state)
  end

  defp handle_attr_value_double_quote(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_attr_value_double_quote(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_attr_value_double_quote(<<>>, line, column, _buffer, _acc, state) do
    raise parse_error("expected closing `\"` for attribute value", line, column, state)
  end

  ## handle_attr_value_single_quote

  defp handle_attr_value_single_quote("\r\n" <> rest, line, _column, buffer, acc, state) do
    column = state.column_offset
    handle_attr_value_single_quote(rest, line + 1, column, ["\r\n" | buffer], acc, state)
  end

  defp handle_attr_value_single_quote("\n" <> rest, line, _column, buffer, acc, state) do
    column = state.column_offset
    handle_attr_value_single_quote(rest, line + 1, column, ["\n" | buffer], acc, state)
  end

  defp handle_attr_value_single_quote("'" <> rest, line, column, buffer, acc, state) do
    value = buffer_to_string(buffer)

    acc =
      update_attr_value(acc, fn {type, _old_value, meta} ->
        {type, value, Map.merge(meta, %{line_end: line, column_end: column})}
      end)

    handle_maybe_tag_open_end(rest, line, column + 1, acc, state)
  end

  defp handle_attr_value_single_quote(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_attr_value_single_quote(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_attr_value_single_quote(<<>>, line, column, _buffer, _acc, state) do
    raise parse_error("expected closing `'` for attribute value", line, column, state)
  end

  ## handle_attr_value_unquoted

  defp handle_attr_value_unquoted(<<c::utf8, _::binary>> = text, line, column, buffer, acc, state)
       when c in @unquoted_value_stop_chars do
    value = buffer_to_string(buffer)

    acc =
      update_attr_value(acc, fn {type, _old_value, meta} ->
        {type, value, Map.merge(meta, %{line_end: line, column_end: column})}
      end)

    handle_maybe_tag_open_end(text, line, column, acc, state)
  end

  defp handle_attr_value_unquoted(<<c::utf8, _::binary>>, line, column, _buffer, _acc, state)
       when c in @unquoted_value_invalid_chars do
    message = """
    unexpected character `#{<<c::utf8>>}`. \
    Unquoted attribute values cannot contain `\"`, `'`, `=` nor `<`
    """

    raise parse_error(message, line, column, state)
  end

  defp handle_attr_value_unquoted(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_attr_value_unquoted(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  ## handle_expression

  # handle tagged expressions
  for marker <- @markers, {maybe_marker, maybe_double_quote} = String.split_at(marker, -1) do
    defp handle_expression(unquote(marker) <> rest = text, line, column, state) do
      marker = unquote(marker)

      {marker, rest} =
        if unquote(maybe_double_quote) == ~S(") do
          unquote(maybe_marker) <> rest = text
          {unquote(maybe_marker), rest}
        else
          {marker, rest}
        end

      marker_column_end = column + String.length(marker)

      meta = %{line: line, column: column, line_end: line, column_end: marker_column_end, file: state.file}

      {rest, line_after_spaces, column_after_spaces} = ignore_spaces(rest, line, marker_column_end, state)

      case handle_expression_value(rest, line_after_spaces, column_after_spaces, state) do
        {:ok, {:expr, value, expr_meta}, new_line, new_column, rest, _state} ->
          expr = if value == "", do: nil, else: {:expr, value, expr_meta}
          {{:tagged_expr, marker, expr, meta}, new_line, new_column, rest}

        {:error, :expected_closing_brace, error_line, error_column} ->
          message = """
          expected closing `}` for tagged expression `{#{marker}` beginning at \
          line: #{line}, column: #{column}\
          """

          raise parse_error(message, error_line, error_column, state)

        {:error, type, line, column} ->
          raise parse_error("parser error: #{inspect(type)}", line, column, state)
      end
    end
  end

  # handle normal expression
  defp handle_expression(text, line, column, state) do
    case handle_expression_value(text, line, column, state) do
      {:ok, expr, new_line, new_column, rest, _state} ->
        {expr, new_line, new_column, rest}

      {:error, :expected_closing_brace, error_line, error_column} ->
        message = """
        expected closing `}` for expression beginning at line: #{line}, column: #{column}\
        """

        raise parse_error(message, error_line, error_column, state)

      {:error, type, line, column} ->
        raise parse_error("parser error: #{inspect(type)}", line, column, state)
    end
  end

  ## handle_expression_value

  defp handle_expression_value(text, line, column, state) do
    case handle_expression_value_end(text, line, column, [], state) do
      {:ok, value, new_line, new_column, rest, state} ->
        meta = %{line: line, column: column, line_end: new_line, column_end: new_column - 1, file: state.file}
        {:ok, {:expr, value, meta}, new_line, new_column, rest, state}

      error ->
        error
    end
  end

  defp handle_expression_value_end("\r\n" <> rest, line, _column, buffer, state) do
    handle_expression_value_end(rest, line + 1, state.column_offset, ["\r\n" | buffer], state)
  end

  defp handle_expression_value_end("\n" <> rest, line, _column, buffer, state) do
    handle_expression_value_end(rest, line + 1, state.column_offset, ["\n" | buffer], state)
  end

  defp handle_expression_value_end("}" <> rest, line, column, buffer, %{braces: []} = state) do
    value = buffer_to_string(buffer)
    {:ok, value, line, column + 1, rest, state}
  end

  defp handle_expression_value_end(~S(\}) <> rest, line, column, buffer, state) do
    handle_expression_value_end(rest, line, column + 2, [~S(\}) | buffer], state)
  end

  defp handle_expression_value_end(~S(\{) <> rest, line, column, buffer, state) do
    handle_expression_value_end(rest, line, column + 2, [~S(\{) | buffer], state)
  end

  defp handle_expression_value_end("}" <> rest, line, column, buffer, state) do
    {_pos, state} = pop_brace(state)
    handle_expression_value_end(rest, line, column + 1, ["}" | buffer], state)
  end

  defp handle_expression_value_end("{" <> rest, line, column, buffer, state) do
    state = push_brace(state, {line, column})
    handle_expression_value_end(rest, line, column + 1, ["{" | buffer], state)
  end

  defp handle_expression_value_end(<<c::utf8, rest::binary>>, line, column, buffer, state) do
    handle_expression_value_end(rest, line, column + 1, [<<c::utf8>> | buffer], state)
  end

  defp handle_expression_value_end(<<>>, line, column, _buffer, _state) do
    {:error, :expected_closing_brace, line, column}
  end

  ## ignore_spaces

  defp ignore_spaces("\r\n" <> rest, line, _column, state) do
    ignore_spaces(rest, line + 1, state.column_offset, state)
  end

  defp ignore_spaces("\n" <> rest, line, _column, state) do
    ignore_spaces(rest, line + 1, state.column_offset, state)
  end

  defp ignore_spaces(<<c::utf8, rest::binary>>, line, column, state) when c in @space_chars do
    ignore_spaces(rest, line, column + 1, state)
  end

  defp ignore_spaces(text, line, column, _state) do
    {text, line, column}
  end

  ## helpers

  defp ok(acc), do: Enum.reverse(acc)

  defp buffer_to_string(buffer) do
    IO.iodata_to_binary(Enum.reverse(buffer))
  end

  defp text_to_acc([], acc), do: acc
  defp text_to_acc(buffer, acc), do: [{:text, buffer_to_string(buffer)} | acc]

  defp put_attr([{:tag_open, name, attrs, meta} | acc], attr, value, attr_meta) do
    attrs = [{attr, value, attr_meta} | attrs]
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp put_attr_value([{:tag_open, name, [{attr, _value, attr_meta} | attrs], meta} | acc], value) do
    attrs = [{attr, value, attr_meta} | attrs]
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp update_attr_value([{:tag_open, name, [{attr, value, attr_meta} | attrs], meta} | acc], fun) do
    attrs = [{attr, fun.(value), attr_meta} | attrs]
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp update_meta([{:tag_open, name, attrs, meta} | acc], values) do
    meta = Map.merge(meta, Map.new(values))

    [{:tag_open, name, attrs, meta} | acc]
  end

  defp reverse_attrs([{:tag_open, name, attrs, meta} | acc]) do
    attrs = Enum.reverse(attrs)
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp push_brace(state, pos) do
    %{state | braces: [pos | state.braces]}
  end

  defp pop_brace(%{braces: [pos | braces]} = state) do
    {pos, %{state | braces: braces}}
  end

  defp macro_tag?(<<"#", first, _rest::binary>>) when first in ?A..?Z, do: true
  defp macro_tag?(_name), do: false

  defp parse_error(message, line, column, state) do
    %ParseError{message: message, file: state.file, line: line, column: column}
  end
end
