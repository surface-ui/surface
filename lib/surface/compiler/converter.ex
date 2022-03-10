defmodule Surface.Compiler.Converter do
  @moduledoc false

  @type subject :: :expr | :tag_name | :attr_name

  @callback opts() :: keyword()
  @callback convert(subject :: subject(), text :: binary(), state :: map(), opts :: keyword()) ::
              binary() | {binary(), state :: map()}
  @callback after_convert_file(ext :: binary(), content :: binary()) :: binary()

  alias Surface.Compiler.Tokenizer

  def convert(text, opts) do
    converter = Keyword.fetch!(opts, :converter)

    metas =
      text
      |> Tokenizer.tokenize!()
      |> extract_meta([], Keyword.merge(opts, converter.opts()))

    state = %{tag_name: nil, tag_open_begin: nil}
    scan_text(text, 1, 1, [], [], metas, state, opts)
  end

  defp scan_text(
         "\r\n" <> rest,
         line,
         column,
         buffer,
         acc,
         [{_type, %{line: line, column: column}} | _] = metas,
         state,
         opts
       ) do
    acc = buffer_to_acc(buffer, acc)
    scan_text(rest, line + 1, 1, ["\r\n"], acc, metas, state, opts)
  end

  defp scan_text(
         "\r\n" <> rest,
         line,
         column,
         buffer,
         acc,
         [{type, %{line_end: line, column_end: column}} | metas],
         state,
         opts
       ) do
    {acc, state} = convert_buffer_to_acc(type, buffer, acc, state, opts)
    scan_text(rest, line + 1, 1, ["\r\n"], acc, metas, state, opts)
  end

  defp scan_text("\r\n" <> rest, line, _column, buffer, acc, metas, state, opts) do
    scan_text(rest, line + 1, 1, ["\r\n" | buffer], acc, metas, state, opts)
  end

  defp scan_text(
         "\n" <> rest,
         line,
         column,
         buffer,
         acc,
         [{_type, %{line: line, column: column}} | _] = metas,
         state,
         opts
       ) do
    acc = buffer_to_acc(buffer, acc)
    scan_text(rest, line + 1, 1, ["\n"], acc, metas, state, opts)
  end

  defp scan_text(
         "\n" <> rest,
         line,
         column,
         buffer,
         acc,
         [{type, %{line_end: line, column_end: column}} | metas],
         state,
         opts
       ) do
    {acc, state} = convert_buffer_to_acc(type, buffer, acc, state, opts)
    scan_text(rest, line + 1, 1, ["\n"], acc, metas, state, opts)
  end

  defp scan_text("\n" <> rest, line, _column, buffer, acc, metas, state, opts) do
    scan_text(rest, line + 1, 1, ["\n" | buffer], acc, metas, state, opts)
  end

  defp scan_text(
         <<c::utf8, rest::binary>>,
         line,
         column,
         buffer,
         acc,
         [{_type, %{line: line, column: column}} | _] = metas,
         state,
         opts
       ) do
    acc = buffer_to_acc(buffer, acc)
    scan_text(rest, line, column + 1, [<<c::utf8>>], acc, metas, state, opts)
  end

  defp scan_text(
         <<c::utf8, rest::binary>>,
         line,
         column,
         buffer,
         acc,
         [{type, %{line_end: line, column_end: column}} | metas],
         state,
         opts
       ) do
    {acc, state} = convert_buffer_to_acc(type, buffer, acc, state, opts)
    scan_text(rest, line, column + 1, [<<c::utf8>>], acc, metas, state, opts)
  end

  defp scan_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, metas, state, opts) do
    scan_text(rest, line, column + 1, [<<c::utf8>> | buffer], acc, metas, state, opts)
  end

  defp scan_text(<<>>, _line, _column, buffer, acc, _metas, _state, _opts) do
    buffer_to_acc(buffer, acc) |> Enum.reverse() |> to_string()
  end

  defp extract_meta([], acc, _opts) do
    acc
  end

  defp extract_meta([node | nodes], acc, opts) do
    acc = extract_meta(nodes, acc, opts)
    extract_meta(node, acc, opts)
  end

  defp extract_meta({:expr, _value, meta}, acc, _opts) do
    [{:expr, meta} | acc]
  end

  defp extract_meta({attr, value, meta}, acc, opts) when is_binary(attr) do
    acc = extract_meta(value, acc, opts)
    [{:attr_name, meta} | acc]
  end

  defp extract_meta({:tag_open, name, attrs, meta}, acc, opts) do
    handle_full_node = Keyword.get(opts, :handle_full_node, [])

    if name in handle_full_node do
      meta_begin = %{
        line: meta.line,
        column: meta.column - 1,
        line_end: meta.line_end,
        column_end: meta.column_end
      }

      meta_end = %{
        line: meta.line_end,
        column: meta.column_end,
        line_end: meta.node_line_end,
        column_end: meta.node_column_end + if(meta[:self_close], do: 2, else: 1)
      }

      [{:tag_open_begin, meta_begin}, {:tag_open_end, meta_end} | acc]
    else
      acc = extract_meta(attrs, acc, opts)
      [{:tag_open_name, meta} | acc]
    end
  end

  defp extract_meta({:tag_close, name, meta}, acc, opts) do
    handle_full_node = Keyword.get(opts, :handle_full_node, [])

    node =
      if name in handle_full_node do
        {:tag_close, %{meta | column: meta.column - 2, column_end: meta.column_end + 1}}
      else
        {:tag_close_name, meta}
      end

    [node | acc]
  end

  defp extract_meta({:string, _name, %{delimiter: nil} = meta}, acc, _opts) do
    [{:unquoted_string, meta} | acc]
  end

  defp extract_meta({:string, _name, %{delimiter: ?"} = meta}, acc, _opts) do
    meta = %{meta | column: meta.column - 1, column_end: meta.column_end + 1}
    [{:double_quoted_string, meta} | acc]
  end

  defp extract_meta(_node, acc, _opts) do
    acc
  end

  defp buffer_to_acc([], acc), do: acc
  defp buffer_to_acc(buffer, acc), do: [buffer_to_string(buffer) | acc]

  defp convert_buffer_to_acc(_type, [], acc, _state, _opts), do: acc

  defp convert_buffer_to_acc(type, buffer, acc, state, opts) do
    converter = Keyword.fetch!(opts, :converter)
    value = buffer_to_string(buffer)

    {new_type, new_state} =
      case type do
        :tag_open_begin -> {:tag_open_begin, %{state | tag_open_begin: value}}
        :tag_close -> {:tag_close, %{state | tag_open_begin: nil}}
        :tag_open_name -> {:tag_name, %{state | tag_name: value}}
        :tag_close_name -> {:tag_name, %{state | tag_name: nil}}
        _ -> {type, state}
      end

    {converted_text, new_state} =
      try do
        case converter.convert(new_type, value, new_state, opts) do
          {test, state} -> {test, state}
          text -> {text, new_state}
        end
      rescue
        exception ->
          message = """
          can't convert token of type #{inspect(new_type)}

          Original type #{inspect(new_type)}

          Value:

          ---
          #{value}
          ---

          Converter state:

            #{inspect(state)}

          Original error:

            #{Exception.message(exception)}
          """

          reraise RuntimeError, [message: message], __STACKTRACE__
      end

    {[converted_text | acc], new_state}
  end

  defp buffer_to_string(buffer) do
    buffer
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end
end
