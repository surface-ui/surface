defmodule Surface.Compiler.CSSParser do
  @moduledoc false
  alias Surface.Compiler.CSSTokenizer

  @other_blocks ["(", "["]

  @opening_symbol %{
    "}" => "{",
    ")" => "(",
    "]" => "["
  }

  def parse!(code, opts \\ []) do
    code
    |> CSSTokenizer.tokenize!(opts)
    |> handle_token(opts)
  end

  defp handle_token(tokens, opts) do
    state = %{
      candidate?: false,
      caller: opts[:caller] || __ENV__
    }

    handle_token(tokens, [[]], state)
  end

  defp handle_token([{:block_open, "{"} | rest], buffers, %{candidate?: true} = state) do
    [buffer | buffers] = buffers
    node = buffer_to_node(buffer, :selector_list)
    buffers = push_node_to_current_buffer(node, buffers)
    buffers = [[] | buffers]
    handle_token(rest, buffers, %{state | candidate?: false})
  end

  defp handle_token([{:block_open, symbol} | rest], buffers, state) when symbol in @other_blocks do
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token([:semicolon = token | rest], buffers, %{candidate?: true} = state) do
    [buffer | buffers] = buffers
    node = buffer_to_node([token | buffer], :declaration)
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, %{state | candidate?: false})
  end

  defp handle_token([{:block_close, "}", meta} | rest], buffers, %{candidate?: true} = state) do
    # handle declaration
    [buffer | buffers] = buffers
    node = buffer_to_node(buffer, :declaration)
    buffers = push_node_to_current_buffer(node, buffers)

    # handle end of block
    [buffer | buffers] = buffers
    node = {:block, "{", Enum.reverse(buffer), convert_block_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)

    handle_token(rest, buffers, %{state | candidate?: false})
  end

  defp handle_token([{:block_close, symbol, meta} | rest], buffers, state) do
    [buffer | buffers] = buffers
    node = {:block, @opening_symbol[symbol], Enum.reverse(buffer), convert_block_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:text, _} = token | rest], buffers, %{candidate?: false} = state) do
    buffers = [[token] | buffers]
    handle_token(rest, buffers, %{state | candidate?: true})
  end

  defp handle_token([token | rest], buffers, state) do
    buffers = push_node_to_current_buffer(token, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([], [buffer], _state) do
    Enum.reverse(buffer)
  end

  defp buffer_to_node(buffer, :selector_list) do
    {reversed, items, list} =
      Enum.reduce(buffer, {[], [], []}, fn
        {:comma, _} = comma, {reversed, [{:ws, _} = space | items], list} ->
          {[comma | reversed], [comma, space], [items | list]}

        {:comma, _} = token, {reversed, items, list} ->
          {[token | reversed], [token], [items | list]}

        token, {reversed, items, list} ->
          {[token | reversed], [token | items], list}
      end)

    list = [items | list]

    case reversed do
      [{:text, "@" <> _} | _] ->
        {:at_rule, reversed}

      _ ->
        {:selector_list, list}
    end
  end

  defp buffer_to_node(buffer, :declaration) do
    case Enum.reverse(buffer) do
      [{:text, "@" <> _} | _] = value ->
        {:at_rule, value}

      value ->
        {:declaration, value}
    end
  end

  defp push_node_to_current_buffer(node, buffers) do
    [buffer | buffers] = buffers
    buffer = [node | buffer]
    [buffer | buffers]
  end

  defp convert_block_meta(meta) do
    %{
      line: meta.opening_line,
      column: meta.opening_column,
      line_end: meta.line,
      column_end: meta.column
    }
  end
end
