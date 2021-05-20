defmodule Surface.Compiler.Tokenizer do
  @moduledoc false
  @space_chars '\n\r\t\f\s'
  @name_stop_chars @space_chars ++ '>/='
  @unquoted_value_invalid_chars '"\'=<`'
  @unquoted_value_stop_chars @space_chars ++ '>'

  alias Surface.Compiler.ParseError

  def tokenize!(text, opts \\ []) do
    file = Keyword.get(opts, :file, "nofile")
    line = Keyword.get(opts, :line, 1)
    column = Keyword.get(opts, :column, 1)
    indentation = Keyword.get(opts, :indentation, 0)

    state = %{file: file, column_offset: indentation + 1, braces: []}

    handle_text(text, line, column, [], [], state)
  end

  ## handle_text

  defp handle_text("<%=" <> _rest, line, column, _buffer, _acc, state) do
    raise parse_error(
            "EEx syntax `<%= foo = :bar %>` not allowed. Please use the Surface interpolation syntax `{{ foo = :bar }}`",
            line,
            column + 4,
            state
          )
  end

  defp handle_text("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_text("\n" <> rest, line, _column, buffer, acc, state) do
    handle_text(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_text("<!--" <> rest, line, column, buffer, acc, state) do
    acc = text_to_acc(buffer, acc)

    {new_rest, new_line, new_column, new_buffer} =
      handle_comment(rest, line, column + 4, ["<!--"], state)

    comment = buffer_to_string(new_buffer)
    handle_text(new_rest, new_line, new_column, [], [{:comment, comment} | acc], state)
  end

  defp handle_text("{" <> rest, line, column, buffer, acc, state) do
    handle_interpolation_in_body(rest, line, column + 1, text_to_acc(buffer, acc), state)
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

  ## handle_interpolation_in_body

  defp handle_interpolation_in_body(text, line, column, acc, state) do
    case handle_interpolation(text, line, column, [], state) do
      {:ok, value, new_line, new_column, rest, state} ->
        meta = %{
          line: line,
          column: column,
          line_end: new_line,
          column_end: new_column - 1,
          file: state.file
        }

        acc = [{:interpolation, value, meta} | acc]
        handle_text(rest, new_line, new_column, [], acc, state)

      {:error, message, line, column} ->
        raise parse_error(message, line, column, state)
    end
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

  ## handle_macro_body

  defp handle_macro_body("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_macro_body(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_macro_body("\n" <> rest, line, _column, buffer, acc, state) do
    handle_macro_body(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_macro_body("</#raw" <> rest, line, column, buffer, acc, state) do
    handle_tag_close(
      "#raw" <> rest,
      line,
      column + 2,
      text_to_acc(buffer, acc),
      state
    )
  end

  defp handle_macro_body("</#" <> <<first, rest::binary>>, line, column, buffer, acc, state)
       when first in ?A..?Z do
    handle_tag_close(
      "#" <> <<first::utf8>> <> rest,
      line,
      column + 2,
      text_to_acc(buffer, acc),
      state
    )
  end

  defp handle_macro_body(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_macro_body(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_macro_body(<<>>, _line, _column, buffer, acc, _state) do
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
          file: state.file
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
        meta = %{
          line: line,
          column: column,
          line_end: line,
          column_end: new_column,
          file: state.file
        }

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

  defp handle_tag_name(<<c::utf8, _rest::binary>>, _column, _buffer = [])
       when c in @name_stop_chars do
    {:error, "expected tag name"}
  end

  defp handle_tag_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @name_stop_chars do
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

  defp handle_maybe_tag_open_end(<<c::utf8, rest::binary>>, line, column, acc, state)
       when c in @space_chars do
    handle_maybe_tag_open_end(rest, line, column + 1, acc, state)
  end

  defp handle_maybe_tag_open_end("/>" <> rest, line, column, acc, state) do
    acc = reverse_attrs(acc)
    handle_text(rest, line, column + 2, [], put_self_close(acc), state)
  end

  defp handle_maybe_tag_open_end(
         ">" <> rest,
         line,
         column,
         [{:tag_open, "#" <> <<first, _::binary>> = name, _, _} | _] = acc,
         state
       )
       when first in ?A..?Z or name == "#raw" do
    acc = reverse_attrs(acc)
    handle_macro_body(rest, line, column + 1, [], acc, state)
  end

  defp handle_maybe_tag_open_end(">" <> rest, line, column, acc, state) do
    acc = reverse_attrs(acc)
    handle_text(rest, line, column + 1, [], acc, state)
  end

  defp handle_maybe_tag_open_end("{" <> rest, line, column, acc, state) do
    handle_root_attribute(rest, line, column + 1, acc, state)
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
        meta = %{
          line: line,
          column: column,
          line_end: line,
          column_end: new_column,
          file: state.file
        }

        acc = put_attr(acc, name, nil, meta)
        handle_maybe_attr_value(rest, line, new_column, acc, state)

      {:error, message} ->
        raise parse_error(message, line, column, state)
    end
  end

  ## handle_root_attribute

  defp handle_root_attribute(text, line, column, acc, state) do
    case handle_interpolation(text, line, column, [], state) do
      {:ok, value, new_line, new_column, rest, state} ->
        meta = %{
          line: line,
          column: column,
          line_end: new_line,
          column_end: new_column - 1,
          file: state.file
        }

        acc = put_attr(acc, :root, {:expr, value, meta}, %{})

        handle_maybe_tag_open_end(rest, new_line, new_column, acc, state)

      {:error, message, line, column} ->
        raise parse_error(message, line, column, state)
    end
  end

  ## handle_attr_name

  defp handle_attr_name(<<c::utf8, _rest::binary>>, _column, [])
       when c in @name_stop_chars do
    {:error, "expected attribute name"}
  end

  defp handle_attr_name(<<c::utf8, _rest::binary>> = text, column, buffer)
       when c in @name_stop_chars do
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

  defp handle_maybe_attr_value(<<c::utf8, rest::binary>>, line, column, acc, state)
       when c in @space_chars do
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

  defp handle_attr_value_begin(<<c::utf8, rest::binary>>, line, column, acc, state)
       when c in @space_chars do
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
    handle_attr_value_as_expr(rest, line, column + 1, acc, state)
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

  ## handle_attr_value_as_expr

  defp handle_attr_value_as_expr(text, line, column, acc, %{braces: []} = state) do
    case handle_interpolation(text, line, column, [], state) do
      {:ok, value, new_line, new_column, rest, state} ->
        meta = %{
          line: line,
          column: column,
          line_end: new_line,
          column_end: new_column - 1,
          file: state.file
        }

        acc = put_attr_value(acc, {:expr, value, meta})
        handle_maybe_tag_open_end(rest, new_line, new_column, acc, state)

      {:error, message, line, column} ->
        raise parse_error(message, line, column, state)
    end
  end

  ## handle_interpolation

  defp handle_interpolation("\r\n" <> rest, line, _column, buffer, state) do
    handle_interpolation(rest, line + 1, state.column_offset, ["\r\n" | buffer], state)
  end

  defp handle_interpolation("\n" <> rest, line, _column, buffer, state) do
    handle_interpolation(rest, line + 1, state.column_offset, ["\n" | buffer], state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, %{braces: []} = state) do
    value = buffer_to_string(buffer)
    {:ok, value, line, column + 1, rest, state}
  end

  defp handle_interpolation(~S(\}) <> rest, line, column, buffer, state) do
    handle_interpolation(rest, line, column + 2, [~S(\}) | buffer], state)
  end

  defp handle_interpolation(~S(\{) <> rest, line, column, buffer, state) do
    handle_interpolation(rest, line, column + 2, [~S(\{) | buffer], state)
  end

  defp handle_interpolation("}" <> rest, line, column, buffer, state) do
    {_pos, state} = pop_brace(state)
    handle_interpolation(rest, line, column + 1, ["}" | buffer], state)
  end

  defp handle_interpolation("{" <> rest, line, column, buffer, state) do
    state = push_brace(state, {line, column})
    handle_interpolation(rest, line, column + 1, ["{" | buffer], state)
  end

  defp handle_interpolation(<<c::utf8, rest::binary>>, line, column, buffer, state) do
    handle_interpolation(rest, line, column + 1, [<<c::utf8>> | buffer], state)
  end

  defp handle_interpolation(<<>>, line, column, _buffer, _state) do
    {:error, "expected closing `}` for expression", line, column}
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

  defp reverse_attrs([{:tag_open, name, attrs, meta} | acc]) do
    attrs = Enum.reverse(attrs)
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp put_self_close([{:tag_open, name, attrs, meta} | acc]) do
    meta = Map.put(meta, :self_close, true)
    [{:tag_open, name, attrs, meta} | acc]
  end

  defp push_brace(state, pos) do
    %{state | braces: [pos | state.braces]}
  end

  defp pop_brace(%{braces: [pos | braces]} = state) do
    {pos, %{state | braces: braces}}
  end

  defp parse_error(message, line, column, state) do
    %ParseError{message: message, file: state.file, line: line, column: column}
  end
end
