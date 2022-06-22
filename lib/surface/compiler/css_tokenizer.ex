defmodule Surface.Compiler.CSSTokenizer do
  alias Surface.Compiler.ParseError

  @ws '\n\r\t '
  @block_open '{(['
  @block_close '})]'
  @quotes [?', ?"]

  @terminator %{
    "{" => "}",
    "(" => ")",
    "[" => "]"
  }

  def tokenize!(text, opts \\ []) do
    file = Keyword.get(opts, :file, "nofile")
    line = Keyword.get(opts, :line, 1)
    column = Keyword.get(opts, :column, 1)
    indentation = Keyword.get(opts, :indentation, 0)

    state = %{file: file, column_offset: indentation + 1, braces: []}

    handle_text(text, line, column, [], [], state)
  end

  ## handle text

  defp handle_text(<<c::utf8, _rest::binary>> = text, line, column, buffer, acc, state) when c in @ws do
    acc = text_to_acc(buffer, acc)
    handle_ws(text, line, column, [], acc, state)
  end

  defp handle_text("*/" <> _, line, column, _buffer, _acc, state) do
    raise parse_error("unexpected end of comment: */", line, column, state)
  end

  defp handle_text("/*" <> rest, line, column, buffer, acc, state) do
    acc = text_to_acc(buffer, acc)
    state = push_brace(state, {"/*", line, column})
    handle_comment(rest, line, column + 2, [], acc, state)
  end

  defp handle_text(";" <> rest, line, column, buffer, acc, state) do
    acc = text_to_acc(buffer, acc)
    handle_text(rest, line, column + 1, [], [:semicolon | acc], state)
  end

  defp handle_text("," <> rest, line, column, buffer, acc, state) do
    acc = text_to_acc(buffer, acc)
    handle_text(rest, line, column + 1, [], [:comma | acc], state)
  end

  defp handle_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) when c in @quotes do
    acc = text_to_acc(buffer, acc)
    state = push_brace(state, {<<c::utf8>>, line, column})
    handle_string(rest, line, column + 1, [], acc, state)
  end

  defp handle_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, state)
       when c in @block_open do
    state = push_brace(state, {<<c::utf8>>, line, column})
    acc = text_to_acc(buffer, acc)
    handle_text(rest, line, column + 1, [], [{:block_open, <<c::utf8>>} | acc], state)
  end

  defp handle_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, state)
       when c in @block_close do
    # TODO: ignore if `symbol != c`
    {_brace, state} = pop_brace(state)
    acc = text_to_acc(buffer, acc)
    handle_text(rest, line, column + 1, [], [{:block_close, <<c::utf8>>} | acc], state)
  end

  defp handle_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_text(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_text(<<>>, _line, _column, buffer, acc, %{braces: []}) do
    ok(text_to_acc(buffer, acc))
  end

  defp handle_text(<<>>, line, column, _buffer, _acc, state) do
    {{symbol, open_line, _column}, _state} = pop_brace(state)

    message =
      ~s(unexpected EOF. The "#{symbol}" at line #{open_line} is missing terminator "#{@terminator[symbol]}")

    raise parse_error(message, line, column, state)
  end

  ## handle white spaces

  defp handle_ws("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_ws(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_ws("\n" <> rest, line, _column, buffer, acc, state) do
    handle_ws(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_ws("\t" <> rest, line, column, buffer, acc, state) do
    handle_ws(rest, line, column + 1, ["\t" | buffer], acc, state)
  end

  defp handle_ws(" " <> rest, line, column, buffer, acc, state) do
    handle_ws(rest, line, column + 1, [" " | buffer], acc, state)
  end

  defp handle_ws(text, line, column, buffer, acc, state) do
    acc = ws_to_acc(buffer, acc)
    handle_text(text, line, column, [], acc, state)
  end

  ## handle comment

  defp handle_comment("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_comment("\n" <> rest, line, _column, buffer, acc, state) do
    handle_comment(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_comment("*/" <> rest, line, column, buffer, acc, state) do
    {{"/*", _line, _column}, state} = pop_brace(state)
    acc = comment_to_acc(buffer, acc)
    handle_text(rest, line, column + 2, [], acc, state)
  end

  defp handle_comment(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_comment(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_comment(<<>>, line, column, _buffer, _acc, state) do
    {{"/*", open_line, open_column}, state} = pop_brace(state)
    message = "expected closing `*/` for `/*` at line #{open_line}, column #{open_column}"
    raise parse_error(message, line, column, state)
  end

  ## handle quoted string

  defp handle_string("\r\n" <> rest, line, _column, buffer, acc, state) do
    handle_string(rest, line + 1, state.column_offset, ["\r\n" | buffer], acc, state)
  end

  defp handle_string("\n" <> rest, line, _column, buffer, acc, state) do
    handle_string(rest, line + 1, state.column_offset, ["\n" | buffer], acc, state)
  end

  defp handle_string("\"" <> rest, line, column, buffer, acc, state) do
    # TODO: raise if `symbol != "\""`
    # {{symbol, open_line, _column}, _state}
    {_brace, state} = pop_brace(state)
    acc = string_to_acc(buffer, "\"", acc)
    handle_text(rest, line, column + 1, [], acc, state)
  end

  defp handle_string("\'" <> rest, line, column, buffer, acc, state) do
    # TODO: raise if `symbol != "\'"`
    # {{symbol, open_line, _column}, _state}
    {_brace, state} = pop_brace(state)
    acc = string_to_acc(buffer, "\'", acc)

    handle_text(rest, line, column + 1, [], acc, state)
  end

  defp handle_string(<<c::utf8, rest::binary>>, line, column, buffer, acc, state) do
    handle_string(rest, line, column + 1, [<<c::utf8>> | buffer], acc, state)
  end

  defp handle_string(<<>>, line, column, _buffer, _acc, state) do
    raise parse_error("expected closing quote for string", line, column, state)
  end

  ## helpers

  defp ok(acc), do: Enum.reverse(acc)

  defp buffer_to_string(buffer) do
    IO.iodata_to_binary(Enum.reverse(buffer))
  end

  defp text_to_acc([], acc), do: acc
  defp text_to_acc(buffer, acc), do: [{:text, buffer_to_string(buffer)} | acc]

  defp string_to_acc([], _delimiter, acc), do: acc
  defp string_to_acc(buffer, delimiter, acc), do: [{:string, delimiter, buffer_to_string(buffer)} | acc]

  defp comment_to_acc([], acc), do: acc
  defp comment_to_acc(buffer, acc), do: [{:comment, buffer_to_string(buffer)} | acc]

  defp ws_to_acc([], acc), do: acc
  defp ws_to_acc(buffer, acc), do: [{:ws, buffer_to_string(buffer)} | acc]

  defp push_brace(state, brace) do
    %{state | braces: [brace | state.braces]}
  end

  # TODO: raise if `%{braces: []}`
  defp pop_brace(%{braces: [pos | braces]} = state) do
    {pos, %{state | braces: braces}}
  end

  defp parse_error(message, line, column, state) do
    %ParseError{message: message, file: state.file, line: line, column: column}
  end
end
