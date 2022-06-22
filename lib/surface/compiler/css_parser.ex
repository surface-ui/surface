defmodule Surface.Compiler.CSSParser do
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

  defp handle_token([:comma = token | rest], buffers, %{candidate?: true} = state) do
    [buffer | buffers] = buffers
    node = buffer_to_node(buffer, :selector)
    buffers = push_node_to_current_buffer(node, buffers)
    buffers = push_node_to_current_buffer(token, buffers)
    handle_token(rest, buffers, %{state | candidate?: false})
  end

  defp handle_token([{:block_open, "{"} | rest], buffers, %{candidate?: true} = state) do
    [buffer | buffers] = buffers
    node = buffer_to_node(buffer, :selector)
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
    node = buffer_to_node(buffer, :declaration)
    buffers = push_node_to_current_buffer(node, buffers)
    buffers = push_node_to_current_buffer(token, buffers)
    handle_token(rest, buffers, %{state | candidate?: false})
  end

  defp handle_token([{:block_close, "}"} | rest], buffers, %{candidate?: true} = state) do
    # handle declaration
    [buffer | buffers] = buffers
    node = buffer_to_node(buffer, :declaration)
    buffers = push_node_to_current_buffer(node, buffers)

    # handle end of block
    [buffer | buffers] = buffers
    node = {:block, "{", Enum.reverse(buffer)}
    buffers = push_node_to_current_buffer(node, buffers)

    handle_token(rest, buffers, %{state | candidate?: false})
  end

  defp handle_token([{:block_close, symbol} | rest], buffers, state) do
    [buffer | buffers] = buffers
    node = {:block, @opening_symbol[symbol], Enum.reverse(buffer)}
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

  defp buffer_to_node(buffer, type) do
    case Enum.reverse(buffer) do
      [{:text, "@" <> _} | _] = value -> {:at_rule, value}
      value -> {type, value}
    end
  end

  defp push_node_to_current_buffer(node, buffers) do
    [buffer | buffers] = buffers
    buffer = [node | buffer]
    [buffer | buffers]
  end
end
