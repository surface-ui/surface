defmodule Surface.Compiler.Converter do
  @moduledoc false

  @type subject :: :interpolation | :tag_name | :attr_name

  @callback convert(subject :: subject(), text :: binary(), state :: map(), opts :: keyword()) ::
              binary()

  alias Surface.Compiler.Tokenizer

  def convert(text, opts) do
    metas =
      text
      |> Tokenizer.tokenize!()
      |> extract_meta([])

    state = %{tag_name: nil}
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

  defp extract_meta([], acc) do
    acc
  end

  defp extract_meta([node | nodes], acc) do
    acc = extract_meta(nodes, acc)
    extract_meta(node, acc)
  end

  defp extract_meta({:interpolation, _value, meta}, acc) do
    [{:interpolation, meta} | acc]
  end

  defp extract_meta({attr, value, meta}, acc) when is_binary(attr) do
    acc = extract_meta(value, acc)
    [{:attr_name, meta} | acc]
  end

  defp extract_meta({:expr, _value, meta}, acc) do
    [{:interpolation, meta} | acc]
  end

  defp extract_meta({:tag_open, _name, attrs, meta}, acc) do
    acc = extract_meta(attrs, acc)
    [{:tag_open, meta} | acc]
  end

  defp extract_meta({:tag_close, _name, meta}, acc) do
    [{:tag_close, meta} | acc]
  end

  defp extract_meta({:string, _name, %{delimiter: nil} = meta}, acc) do
    [{:unquoted_string, meta} | acc]
  end

  defp extract_meta(_node, acc) do
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
        :tag_open -> {:tag_name, %{state | tag_name: value}}
        :tag_close -> {:tag_name, %{state | tag_name: nil}}
        _ -> {type, state}
      end

    {[converter.convert(new_type, value, new_state, opts) | acc], new_state}
  end

  defp buffer_to_string(buffer) do
    buffer
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end
end
