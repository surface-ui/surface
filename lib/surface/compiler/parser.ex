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

  @sub_blocks [
    "#else",
    "#elseif",
    "#match"
  ]

  @sub_blocks_valid_parents %{
    "#else" => ["#if", "#for"],
    "#elseif" => ["#if"],
    "#match" => ["#case"]
  }

  def parse!(code, opts \\ []) do
    code
    |> Tokenizer.tokenize!(opts)
    |> handle_token()
  end

  def parse(code, opts \\ []) do
    try do
      {:ok, parse!(code, opts)}
    rescue
      e in [ParseError] ->
        {:error, e.message, %{file: e.file, line: e.line, column: e.column}}
    end
  end

  defp handle_token(tokens) do
    handle_token(tokens, [[]], %{tags: []})
  end

  defp handle_token([], [buffer], _state) do
    Enum.reverse(buffer)
  end

  defp handle_token([], _buffers, %{tags: [{:tag_open, tag_name, _attrs, meta} | _]}) do
    raise parse_error(
            "expected closing tag for <#{tag_name}> defined on line #{meta.line}, got EOF",
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

  defp handle_token([{:interpolation, expr, meta} | rest], buffers, state) do
    buffers = push_node_to_current_buffer({:interpolation, expr, to_meta(meta)}, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, meta} = token | rest], buffers, state)
       when name in @sub_blocks do
    with {:ok, buffers, state} <- close_sub_block(token, buffers, state) do
      # push the current sub-block token to state
      state = push_tag(state, {:tag_open, name, attrs, meta})

      # create a new buffer for the current sub-block
      buffers = [[] | buffers]

      handle_token(rest, buffers, state)
    end
  end

  defp handle_token([{:tag_open, name, attrs, meta} | rest], buffers, state)
       when name in @void_elements do
    with {:ok, translated_attrs} <- transtate_attrs(attrs) do
      node = {name, translated_attrs, [], to_meta(meta)}
      buffers = push_node_to_current_buffer(node, buffers)
      handle_token(rest, buffers, state)
    end
  end

  defp handle_token([{:tag_open, name, attrs, %{self_close: true} = meta} | rest], buffers, state) do
    with {:ok, translated_attrs} <- transtate_attrs(attrs) do
      node = {name, translated_attrs, [], to_meta(meta)}
      buffers = push_node_to_current_buffer(node, buffers)
      handle_token(rest, buffers, state)
    end
  end

  defp handle_token([{:tag_open, _name, _attrs, _meta} = token | rest], buffers, state) do
    state = push_tag(state, token)
    # create a new buffer for the node
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token(
         [{:tag_close, _name, _meta} = token | _] = tokens,
         buffers,
         %{tags: [{:tag_open, name, _, _} | _]} = state
       )
       when name in @sub_blocks do
    with {:ok, buffers, state} <- close_sub_block(token, buffers, state) do
      handle_token(tokens, buffers, state)
    end
  end

  defp handle_token([{:tag_close, name, _meta} | rest], buffers, state) do
    with {:ok, {{:tag_open, _name, attrs, meta}, state}} <- pop_matching_tag(state, name),
         {:ok, translated_attrs} <- transtate_attrs(attrs) do
      # pop the current buffer and use it as children for the node
      [buffer | buffers] = buffers
      node = {name, translated_attrs, Enum.reverse(buffer), to_meta(meta)}
      buffers = push_node_to_current_buffer(node, buffers)
      handle_token(rest, buffers, state)
    end
  end

  # IF there's a previous sub-block defined. Close it.
  defp close_sub_block(_token, buffers, %{tags: [{:tag_open, name, attrs, meta} | tags]} = state)
       when name in @sub_blocks do
    with {:ok, translated_attrs} <- transtate_attrs(attrs) do
      # pop the current buffer and use it as children for the sub-block node
      [buffer | buffers] = buffers
      node = {name, translated_attrs, Enum.reverse(buffer), to_meta(meta)}
      buffers = push_node_to_current_buffer(node, buffers)
      state = %{state | tags: tags}

      {:ok, buffers, state}
    end
  end

  # If there's no previous sub-block defined. Create a :default sub-block,
  # move the buffer there and close it.
  defp close_sub_block(token, buffers, %{tags: [{:tag_open, name, attrs, meta} | tags]} = state) do
    with :ok <- sub_block_valid?(token, name) do
      # pop the current buffer and use it as children for the :default sub-block node
      [buffer | buffers] = buffers
      node = {:default, [], Enum.reverse(buffer), %{}}

      # create a new buffer for the parent node to replace the one that was popped
      buffers = [[] | buffers]
      buffers = push_node_to_current_buffer(node, buffers)

      # push back the parent token to state
      meta = Map.put(meta, :has_sub_blocks?, true)
      state = %{state | tags: [{:tag_open, name, attrs, meta} | tags]}

      {:ok, buffers, state}
    end
  end

  defp close_sub_block({:tag_open, name, _attrs, meta}, _buffers, _state) do
    valid_parents_str = message_for_invalid_sub_block_parent(name)

    raise parse_error("no valid parent node defined for <#{name}>. #{valid_parents_str}", meta)
  end

  defp sub_block_valid?({:tag_open, name, _attrs, meta}, parent_name) do
    valid_parents_str = message_for_invalid_sub_block_parent(name)

    if parent_name in @sub_blocks_valid_parents[name] do
      :ok
    else
      raise parse_error(
              "cannot use <#{name}> inside <#{parent_name}>. #{valid_parents_str}",
              meta
            )
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
    Map.drop(meta, [:self_close, :line_end, :column_end])
  end

  defp push_node_to_current_buffer(node, buffers) do
    [buffer | buffers] = buffers
    buffer = [node | buffer]
    [buffer | buffers]
  end

  defp transtate_attrs([]), do: {:ok, []}

  defp transtate_attrs([attr | attrs]) do
    with {:ok, translated_attr} <- translate_attr(attr),
         {:ok, translated_attrs} <- transtate_attrs(attrs) do
      {:ok, [translated_attr | translated_attrs]}
    end
  end

  defp translate_attr({name, {:string, value, %{delimiter: ?"}}, meta}) do
    {:ok, {name, value, to_meta(meta)}}
  end

  defp translate_attr({name, {:string, "true", %{delimiter: nil}}, meta}) do
    {:ok, {name, true, to_meta(meta)}}
  end

  defp translate_attr({name, {:string, "false", %{delimiter: nil}}, meta}) do
    {:ok, {name, false, to_meta(meta)}}
  end

  defp translate_attr({name, {:string, value, %{delimiter: nil}}, meta}) do
    case Integer.parse(value) do
      {int_value, ""} ->
        {:ok, {name, int_value, to_meta(meta)}}

      _ ->
        raise parse_error("unexpected value for attribute \"#{name}\"", meta)
    end
  end

  defp translate_attr({:root, {:expr, value, expr_meta}, _attr_meta}) do
    meta = to_meta(expr_meta)
    {:ok, {:root, {:attribute_expr, value, meta}, meta}}
  end

  defp translate_attr({name, {:expr, value, expr_meta}, attr_meta}) do
    {:ok, {name, {:attribute_expr, value, to_meta(expr_meta)}, to_meta(attr_meta)}}
  end

  defp translate_attr({name, nil, meta}) do
    {:ok, {name, true, to_meta(meta)}}
  end

  defp push_tag(state, {:tag_open, tag, _attrs, _meta}) when tag in @void_elements do
    state
  end

  defp push_tag(state, token) do
    %{state | tags: [token | state.tags]}
  end

  defp pop_matching_tag(%{tags: [{:tag_open, tag_name, _, _} = tag | tags]} = state, tag_name) do
    {:ok, {tag, %{state | tags: tags}}}
  end

  defp pop_matching_tag(%{tags: [{:tag_open, tag_name, _attrs, meta} | _]}, closed_node_name) do
    message = """
    expected closing tag for <#{tag_name}> defined on line #{meta.line}, got </#{closed_node_name}>\
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
end
