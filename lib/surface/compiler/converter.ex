defmodule Surface.Compiler.Converter do
  @moduledoc false

  @type subject :: :interpolation | :tag_name | :attr_name

  @callback convert(subject :: subject(), text :: binary(), opts :: keyword()) :: binary()

  alias Surface.Compiler.Tokenizer

  def convert(text, opts) do
    metas =
      text
      |> Tokenizer.tokenize()
      |> extract_meta([])

    scan_text(text, 1, 1, [], [], metas, opts)
  end

  defp scan_text("\r\n" <> rest, line, column, buffer, acc, [{type, %{line_end: line, column_end: column}} | metas], opts) do
    scan_text(rest, line + 1, 1, ["\r\n"], convert_buffer_to_acc(type, buffer, acc, opts), metas, opts)
  end

  defp scan_text("\r\n" <> rest, line, _column, buffer, acc, metas, opts) do
    scan_text(rest, line + 1, 1, ["\r\n" | buffer], acc, metas, opts)
  end

  defp scan_text("\n" <> rest, line, column, buffer, acc, [{type, %{line_end: line, column_end: column}} | metas], opts) do
    scan_text(rest, line + 1, 1, ["\n"], convert_buffer_to_acc(type, buffer, acc, opts), metas, opts)
  end

  defp scan_text("\n" <> rest, line, _column, buffer, acc, metas, opts) do
    scan_text(rest, line + 1, 1, ["\n" | buffer], acc, metas, opts)
  end

  defp scan_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, [{_type, %{line: line, column: column}} | _] = metas, opts) do
    scan_text(rest, line, column + 1, [<<c::utf8>>], buffer_to_acc(buffer, acc), metas, opts)
  end

  defp scan_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, [{type, %{line_end: line, column_end: column}} | metas], opts) do
    scan_text(rest, line, column + 1, [<<c::utf8>>], convert_buffer_to_acc(type, buffer, acc, opts), metas, opts)
  end

  defp scan_text(<<c::utf8, rest::binary>>, line, column, buffer, acc, metas, opts) do
    scan_text(rest, line, column + 1, [<<c::utf8>> | buffer], acc, metas, opts)
  end

  defp scan_text(<<>>, _line, _column, buffer, acc, _metas, _opts) do
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
    [{:tag_name, meta} | acc]
  end

  defp extract_meta({:tag_close, _name, meta}, acc) do
    [{:tag_name, meta} | acc]
  end

  defp extract_meta({:unquoted_string, _name, meta}, acc) do
    [{:unquoted_string, meta} | acc]
  end

  defp extract_meta(_node, acc) do
    acc
  end

  defp buffer_to_acc([], acc), do: acc
  defp buffer_to_acc(buffer, acc), do: [buffer_to_string(buffer) | acc]

  defp convert_buffer_to_acc(_type, [], acc, _opts), do: acc
  defp convert_buffer_to_acc(type, buffer, acc, opts) do
    converter = Keyword.fetch!(opts, :converter)
    [converter.convert(type, buffer_to_string(buffer), opts) | acc]
  end

  defp buffer_to_string(buffer) do
    buffer
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end
end
