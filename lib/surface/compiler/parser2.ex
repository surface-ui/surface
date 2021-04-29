defmodule Surface.Compiler.Parser2 do
  @moduledoc false

  alias Surface.Compiler.Tokenizer
  alias Surface.Compiler.Tokenizer.ParseError
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

  @sub_blocks [
    "#else",
    "#elseif",
    "#match"
  ]

  @sub_blocks_valid_parents %{
    "#else" => ["#if", "#for"],
    "#elseif" => ["#if"],
    "#match" => ["#case"],
  }

  def parse(code) do
    try do
      tokens = Tokenizer.tokenize(code)
      case handle_token(tokens) do
        ast when is_list(ast) ->
          {:ok, ast}

        error ->
          error
      end

    rescue
      e in [ParseError] ->
        %ParseError{line: line, column: _column, message: message} = e
        {:error, message, line}
      end
  end

  defp handle_token(tokens) do
    handle_token(tokens, [[]], %{tags: []})
  end

  defp handle_token([], [buffer], _state) do
    Enum.reverse(buffer)
  end

  defp handle_token([], _buffers, %{tags: [{:tag_open, tag_name, _attrs, %{line: line}} | _]}) do
    {:error, "expected closing tag for <#{tag_name}>", line}
  end

  defp handle_token([{:text, text} | rest], buffers, state) do
    buffers = push_node_to_current_buffer(text, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:comment, comment} | rest], buffers, state) do
    buffers = push_node_to_current_buffer({:comment, comment}, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:interpolation, expr, meta} | rest], buffers, state) do
    buffers = push_node_to_current_buffer({:interpolation, expr, to_meta(meta)}, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, meta} = token | rest], buffers, state) when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)

    # push the current sub-block token to state
    state = push_tag(state, {:tag_open, name, attrs, meta})

    # create a new buffer for the current sub-block
    buffers = [[] | buffers]

    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, meta} | rest], buffers, state) when name in @void_elements do
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

  defp handle_token([{:tag_close, _name, _meta} = token | _] = tokens, buffers, %{tags: [{:tag_open, name, _, _} | _]} = state)
       when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)
    handle_token(tokens, buffers, state)
  end

  defp handle_token([{:tag_close, name, _meta} | rest], buffers, state) do
    case pop_matching_tag(state, name) do
      {:ok, {{:tag_open, _name, attrs, meta}, state}} ->
        # pop the current buffer and use it as children for the node
        [buffer | buffers] = buffers
        node = {name, transtate_attrs(attrs), Enum.reverse(buffer), to_meta(meta)}
        buffers = push_node_to_current_buffer(node, buffers)
        handle_token(rest, buffers, state)

      error ->
        error
    end
  end

  # IF there's a previous sub-block defined. Close it.
  defp close_sub_block(_token, buffers, %{tags: [{:tag_open, name, attrs, meta} | tags]} = state)
       when name in @sub_blocks do
    # pop the current buffer and use it as children for the sub-block node
    [buffer | buffers] = buffers
    node = {name, transtate_attrs(attrs), Enum.reverse(buffer), to_meta(meta)}
    buffers = push_node_to_current_buffer(node, buffers)
    state = %{state | tags: tags}

    {buffers, state}
  end

  # If there's no previous sub-block defined. Create a :default sub-block,
  # move the buffer there and close it.
  defp close_sub_block(token, buffers, %{tags: [{:tag_open, name, attrs, meta} | tags]} = state) do
    validate_sub_block!(token, name)

    # pop the current buffer and use it as children for the :default sub-block node
    [buffer | buffers] = buffers
    node = {:default, [], Enum.reverse(buffer), %{}}

    # create a new buffer for the parent node to replace the one that was popped
    buffers = [[] | buffers]
    buffers = push_node_to_current_buffer(node, buffers)

    # push back the parent token to state
    meta = Map.put(meta, :has_sub_blocks?, true)
    state = %{state | tags: [{:tag_open, name, attrs, meta} | tags]}

    {buffers, state}
  end

  defp close_sub_block({:tag_open, name, _attrs, meta}, _buffers, _state) do
    %{line: line, column: column} = meta
    valid_parents_str = message_for_invalid_sub_block_parent(name)

    message = "no valid parent node defined for <#{name}>. #{valid_parents_str}"
    raise %ParseError{line: line, column: column, message: message}
  end

  defp validate_sub_block!({:tag_open, name, _attrs, meta}, parent_name) do
    %{line: line, column: column} = meta
    valid_parents_str = message_for_invalid_sub_block_parent(name)

    if parent_name not in @sub_blocks_valid_parents[name] do
      message = "cannot use <#{name}> inside <#{parent_name}>. #{valid_parents_str}"
      raise %ParseError{line: line, column: column, message: message}
    end
  end

  defp message_for_invalid_sub_block_parent(name) do
    valid_parents = @sub_blocks_valid_parents[name]
    valid_parents_tags = Enum.map(valid_parents, &"<#{&1}>")

    Helpers.list_to_string(
      "The <#{name}> construct can only be used inside a",
      "Possible parents are",
      valid_parents_tags
    )
  end

  defp to_meta(meta) do
    Map.drop(meta, [:self_close, :column, :line_end, :column_end])
  end

  defp push_node_to_current_buffer(node, buffers) do
    [buffer | buffers] = buffers
    buffer = [node | buffer]
    [buffer | buffers]
  end

  defp transtate_attrs(attrs) do
    Enum.map(attrs, &translate_attr/1)
  end

  defp translate_attr({name, {:string, value, %{delimiter: ?"}}, %{line: line}}) do
    {name, value, %{line: line}}
  end

  defp translate_attr({name, {:unquoted_string, "true", %{}}, %{line: line}}) do
    {name, true, %{line: line}}
  end

  defp translate_attr({name, {:unquoted_string, "false", %{}}, %{line: line}}) do
    {name, false, %{line: line}}
  end

  defp translate_attr({name, {:unquoted_string, value, %{}}, %{line: line}}) do
    case Integer.parse(value) do
      {int_value, ""} ->
        {name, int_value, %{line: line}}

      _ ->
        message = "unexpected value for attribute \"#{name}\""
        raise %ParseError{line: line, column: 1, message: message}
    end
  end

  defp translate_attr({:root, {:expr, value, expr_meta}, _attr_meta}) do
    {:root, {:attribute_expr, value, %{line: expr_meta.line}}, %{line: expr_meta.line}}
  end

  defp translate_attr({name, {:expr, value, expr_meta}, attr_meta}) do
    {name, {:attribute_expr, value, %{line: expr_meta.line}}, %{line: attr_meta.line}}
  end

  defp translate_attr({name, nil, %{line: line}}) do
    {name, true, %{line: line}}
  end

  defp push_tag(state, {:tag_open, tag, _attrs, _meta}) when tag in @void_elements do
    state
  end

  defp push_tag(state, token) do
    %{state | tags: [token | state.tags]}
  end

  defp pop_matching_tag(%{tags: [{:tag_open, tag_name, _attrs, _meta} = tag | tags]} = state, tag_name) do
    {:ok, {tag, %{state | tags: tags}}}
  end

  defp pop_matching_tag(%{tags: [{:tag_open, tag_name, _attrs, %{line: line}} | _]}, _) do
    # TODO: change message to "expected closing tag for <bar> defined at line 4, got </foo>"
    {:error, "expected closing tag for <#{tag_name}>", line}
  end
end
