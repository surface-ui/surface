defmodule Surface.Compiler.Parser do
  @moduledoc false

  alias Surface.Compiler.Tokenizer
  alias Surface.Compiler.ParseError
  alias Surface.Compiler.Helpers

  @void_elements [
    "area",
    "base",
    "br",
    "col",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "param",
    "command",
    "keygen",
    "source"
  ]

  @blocks [
    "if",
    "unless",
    "for",
    "case",
    "else",
    "elseif",
    "match"
  ]

  @sub_blocks [
    "else",
    "elseif",
    "match"
  ]

  @sub_blocks_valid_parents %{
    "else" => ["if", "for"],
    "elseif" => ["if"],
    "match" => ["case"]
  }

  def parse!(code, opts \\ []) do
    code
    |> Tokenizer.tokenize!(opts)
    |> handle_token()
  end

  defp handle_token(tokens) do
    handle_token(tokens, [[]], %{tags: []})
  end

  defp handle_token([], [buffer], _state) do
    Enum.reverse(buffer)
  end

  defp handle_token([], _buffers, %{tags: [{_, _name, _attrs, meta} = node | _]}) do
    raise parse_error(
            "expected closing node for #{format_node(node)} defined on line #{meta.line}, got EOF",
            meta
          )
  end

  defp handle_token([{:text, text} | rest], buffers, state) do
    buffers = push_node_to_current_buffer(text, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:comment, comment} | rest], buffers, state) do
    buffers = push_node_to_current_buffer({:comment, comment}, buffers)
    handle_token(rest, buffers, state)
  end

  # This is mostly a temporary solution until we decide whether this logic
  # should be moved to the tokenizer or not. We could also hold the expression
  # directly instead of using the :root attribute.
  for block <- @blocks do
    defp handle_token([{:interpolation, "#" <> unquote(block) <> " " <> expr, meta} | rest], buffers, state) do
      expr_meta = %{meta | column: meta.column + String.length(unquote(block)) + 2}
      attrs = [{:root, {:expr, expr, expr_meta}, expr_meta}]
      handle_token([{:block_open, unquote(block), attrs, meta} | rest], buffers, state)
    end

    defp handle_token([{:interpolation, "#" <> unquote(block), meta} | rest], buffers, state) do
      handle_token([{:block_open, unquote(block), [], meta} | rest], buffers, state)
    end

    defp handle_token([{:interpolation, "/" <> unquote(block), meta} | rest], buffers, state) do
      handle_token([{:block_close, unquote(block), meta} | rest], buffers, state)
    end
  end

  defp handle_token([{:interpolation, expr, meta} | rest], buffers, state) do
    buffers = push_node_to_current_buffer({:interpolation, expr, to_meta(meta)}, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_open, name, attrs, meta} = token | rest], buffers, state)
       when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)

    # push the current sub-block token to state
    state = push_tag(state, {:block_open, name, attrs, meta})

    # create a new buffer for the current sub-block
    buffers = [[] | buffers]

    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, meta} | rest], buffers, state)
       when name in @void_elements do
    node = {name, transtate_attrs(attrs), [], to_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, %{self_close: true} = meta} | rest], buffers, state) do
    node = {name, transtate_attrs(attrs), [], to_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, _name, _attrs, _meta} = token | rest], buffers, state) do
    state = push_tag(state, token)
    # create a new buffer for the node
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_open, _name, _attrs, _meta} = token | rest], buffers, state) do
    state = push_tag(state, token)
    # create a new buffer for the node
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token(
         [{:block_close, _name, _meta} = token | _] = tokens,
         buffers,
         %{tags: [{:block_open, name, _, _} | _]} = state
       )
       when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)
    handle_token(tokens, buffers, state)
  end

  defp handle_token([{:tag_close, name, _meta} = token | rest], buffers, state) do
    {{:tag_open, _name, attrs, meta}, state} = pop_matching_tag(state, token)

    # pop the current buffer and use it as children for the node
    [buffer | buffers] = buffers
    node = {name, transtate_attrs(attrs), Enum.reverse(buffer), to_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_close, name, _meta} = token | rest], buffers, state) do
    {{:block_open, _name, attrs, meta}, state} = pop_matching_tag(state, token)

    # pop the current buffer and use it as children for the node
    [buffer | buffers] = buffers
    node = {:block, name, transtate_attrs(attrs), Enum.reverse(buffer), to_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  # If there's a previous sub-block defined. Close it.
  defp close_sub_block(_token, buffers, %{tags: [{:block_open, name, attrs, meta} | tags]} = state)
       when name in @sub_blocks do
    # pop the current buffer and use it as children for the sub-block node
    [buffer | buffers] = buffers
    node = {:block, name, transtate_attrs(attrs), Enum.reverse(buffer), to_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)
    state = %{state | tags: tags}

    {buffers, state}
  end

  # If there's no previous sub-block defined. Create a :default sub-block,
  # move the buffer there and close it.
  defp close_sub_block(token, buffers, %{tags: [{:block_open, name, attrs, meta} | tags]} = state) do
    validate_sub_block!(token, name)

    # pop the current buffer and use it as children for the :default sub-block node
    [buffer | buffers] = buffers
    node = {:block, :default, [], Enum.reverse(buffer), %{}}

    # create a new buffer for the parent node to replace the one that was popped
    buffers = [[] | buffers]
    buffers = push_node_to_current_buffer(node, buffers)

    # push back the parent token to state
    meta = Map.put(meta, :has_sub_blocks?, true)
    state = %{state | tags: [{:block_open, name, attrs, meta} | tags]}

    {buffers, state}
  end

  # If there's no parent node
  defp close_sub_block({:block_open, name, _attrs, meta}, _buffers, _state) do
    message = message_for_invalid_sub_block_parent(name)
    raise parse_error(message, meta)
  end

  defp validate_sub_block!({:block_open, name, _attrs, meta}, parent_name) do
    if parent_name not in @sub_blocks_valid_parents[name] do
      message = message_for_invalid_sub_block_parent(name)
      raise parse_error(message, meta)
    end
  end

  defp message_for_invalid_sub_block_parent(name) do
    valid_parents = @sub_blocks_valid_parents[name]
    valid_parents_tags = Enum.map(valid_parents, &"{##{&1}}")

    "no valid parent node defined for {##{name}}. " <>
      Helpers.list_to_string(
        "The {##{name}} construct can only be used inside a",
        "Possible parents are",
        valid_parents_tags
      )
  end

  defp to_meta(meta) do
    Map.drop(meta, [:self_close, :line_end, :column_end])
  end

  defp push_node_to_current_buffer(node, buffers) do
    [buffer | buffers] = buffers
    buffer = [node | buffer]
    [buffer | buffers]
  end

  defp transtate_attrs(attrs),
    do: Enum.map(attrs, &translate_attr/1)

  defp translate_attr({name, {:string, value, %{delimiter: ?"}}, meta}) do
    {name, value, to_meta(meta)}
  end

  defp translate_attr({name, {:string, "true", %{delimiter: nil}}, meta}) do
    meta = Map.put(meta, :unquoted_string?, true)
    {name, true, to_meta(meta)}
  end

  defp translate_attr({name, {:string, "false", %{delimiter: nil}}, meta}) do
    meta = Map.put(meta, :unquoted_string?, true)
    {name, false, to_meta(meta)}
  end

  defp translate_attr({name, {:string, value, %{delimiter: nil}}, meta}) do
    case Integer.parse(value) do
      {int_value, ""} ->
        meta = Map.put(meta, :unquoted_string?, true)
        {name, int_value, to_meta(meta)}

      _ ->
        raise parse_error("unexpected value for attribute \"#{name}\"", meta)
    end
  end

  defp translate_attr({:root, {:expr, value, expr_meta}, _attr_meta}) do
    meta = to_meta(expr_meta)
    {:root, {:attribute_expr, value, meta}, meta}
  end

  defp translate_attr({name, {:expr, value, expr_meta}, attr_meta}) do
    {name, {:attribute_expr, value, to_meta(expr_meta)}, to_meta(attr_meta)}
  end

  defp translate_attr({name, nil, meta}) do
    {name, true, to_meta(meta)}
  end

  defp push_tag(state, {:tag_open, tag, _attrs, _meta}) when tag in @void_elements do
    state
  end

  defp push_tag(state, token) do
    %{state | tags: [token | state.tags]}
  end

  defp pop_matching_tag(%{tags: [{:tag_open, tag_name, _, _} = tag | tags]} = state, {:tag_close, tag_name, _}) do
    {tag, %{state | tags: tags}}
  end

  defp pop_matching_tag(%{tags: [{:block_open, name, _, _} = tag | tags]} = state, {:block_close, name, _}) do
    {tag, %{state | tags: tags}}
  end

  defp pop_matching_tag(%{tags: [{_, _, _, meta} = token_open | _]}, token_close) do
    message = """
    expected closing node for #{format_node(token_open)} defined on line #{meta.line}, \
    got #{format_node(token_close)}\
    """

    raise parse_error(message, meta)
  end

  defp parse_error(message, meta) do
    %ParseError{
      message: message,
      file: meta.file,
      line: meta.line,
      column: meta.column
    }
  end

  defp format_node({:tag_open, name, _attrs, _meta}), do: "<#{name}>"
  defp format_node({:tag_close, name, _meta}), do: "</#{name}>"
  defp format_node({:block_open, name, _attrs, _meta}), do: "{##{name}}"
  defp format_node({:block_close, name, _meta}), do: "{/#{name}}"
end
