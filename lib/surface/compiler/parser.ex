defmodule Surface.Compiler.Parser do
  @moduledoc false

  alias Surface.Compiler.Tokenizer
  alias Surface.Compiler.ParseError
  alias Surface.Compiler.Helpers

  @blocks [
    "if",
    "unless",
    "for",
    "case"
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
    |> handle_token(opts)
  end

  defp handle_token(tokens, opts) do
    state = %{
      translator: opts[:translator] || Surface.Compiler.ParseTreeTranslator,
      tags: [],
      caller: opts[:caller] || __ENV__,
      checks: opts[:checks] || [],
      warnings: opts[:warnings] || []
    }

    handle_token(tokens, [[]], state.translator.handle_init(state))
  end

  defp handle_token([], [buffer], _state) do
    Enum.reverse(buffer)
  end

  defp handle_token([], _buffers, %{tags: [{{_, _name, _attrs, meta} = node, _ctx} | _]}) do
    raise parse_error(
            "expected closing node for #{format_node(node)} defined on line #{meta.line}, got EOF",
            meta
          )
  end

  defp handle_token([{:text, text} | rest], buffers, state) do
    {state, node} = state.translator.handle_literal(state, text)
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:comment, comment, meta} | rest], buffers, state) do
    {state, node} = state.translator.handle_comment(state, comment, meta)

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:expr, expr, meta} | rest], buffers, state) do
    {state, node} = state.translator.handle_expression(state, expr, meta)

    buffers = push_node_to_current_buffer(node, buffers)

    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, %{void_tag?: true} = meta} | rest], buffers, state) do
    context = state.translator.context_for_node(state, name, meta)

    {state, node} =
      state.translator.handle_node(
        state,
        context,
        name,
        translate_attrs(state, context, attrs),
        [],
        meta
      )

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, %{self_close: true} = meta} | rest], buffers, state) do
    context = state.translator.context_for_node(state, name, meta)

    {state, node} =
      state.translator.handle_node(
        state,
        context,
        name,
        translate_attrs(state, context, attrs),
        [],
        meta
      )

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, _attrs, meta} = token | rest], buffers, state) do
    context = state.translator.context_for_node(state, name, meta)
    state = push_tag(state, token, context)
    # create a new buffer for the node
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_close, name, _meta} = token | rest], buffers, state) do
    {{:tag_open, _name, attrs, meta}, context, state} = pop_matching_tag(state, token)

    # pop the current buffer and use it as children for the node
    [buffer | buffers] = buffers

    {state, node} =
      state.translator.handle_node(
        state,
        context,
        name,
        translate_attrs(state, context, attrs),
        Enum.reverse(buffer),
        meta
      )

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  # TODO: Remove these after accepting the expression directly instead of the :root attribute
  defp handle_token(
         [{:block_open, name, {:expr, expr, expr_meta}, meta} | rest],
         buffers,
         state
       ) do
    attrs = [{:root, {:expr, expr, expr_meta}, expr_meta}]
    handle_token([{:block_open, name, attrs, meta} | rest], buffers, state)
  end

  defp handle_token([{:block_open, name, nil, meta} | rest], buffers, state) do
    handle_token([{:block_open, name, [], meta} | rest], buffers, state)
  end

  ###

  defp handle_token([{:block_open, name, attrs, meta} = token | rest], buffers, state)
       when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)

    context = state.translator.context_for_subblock(state, name, parent_context(state.tags), meta)

    # push the current sub-block token to state
    state = push_tag(state, {:block_open, name, attrs, meta}, context)

    # create a new buffer for the current sub-block
    buffers = [[] | buffers]

    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_open, name, _attrs, meta} = token | rest], buffers, state)
       when name in @blocks do
    context = state.translator.context_for_block(state, name, meta)

    state = push_tag(state, token, context)
    # create a new buffer for the node
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_open, name, _attrs, meta} | _], _buffers, _state) do
    blocks = Helpers.list_to_string("block is", "blocks are", @blocks ++ @sub_blocks)
    raise parse_error("unknown `{##{name}}` block. Available #{blocks}", meta)
  end

  defp handle_token(
         [{:block_close, _name, _meta} = token | _] = tokens,
         buffers,
         %{tags: [{{:block_open, name, _, _}, _} | _]} = state
       )
       when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)
    handle_token(tokens, buffers, state)
  end

  defp handle_token([{:block_close, name, _meta} = token | rest], buffers, state)
       when name in @blocks do
    {{:block_open, _name, attrs, meta}, context, state} = pop_matching_tag(state, token)

    # pop the current buffer and use it as children for the node
    [buffer | buffers] = buffers

    {state, node} =
      state.translator.handle_block(
        state,
        context,
        name,
        translate_attrs(state, context, attrs),
        Enum.reverse(buffer),
        meta
      )

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{{:block_close, name, meta}, _ctx} | _], _buffers, _state) do
    blocks = Helpers.list_to_string("block is", "blocks are", @blocks)
    raise parse_error("unknown `{/#{name}}` block. Available #{blocks}", meta)
  end

  # If there's a previous sub-block defined. Close it.
  defp close_sub_block(
         _token,
         buffers,
         %{tags: [{{:block_open, name, attrs, meta}, context} | tags]} = state
       )
       when name in @sub_blocks do
    # pop the current buffer and use it as children for the sub-block node
    [buffer | buffers] = buffers

    {state, node} =
      state.translator.handle_subblock(
        state,
        context,
        name,
        translate_attrs(state, context, attrs),
        Enum.reverse(buffer),
        meta
      )

    state = %{state | tags: tags}
    buffers = push_node_to_current_buffer(node, buffers)

    {buffers, state}
  end

  # If there's no previous sub-block defined. Create a :default sub-block,
  # move the buffer there and close it.
  defp close_sub_block(
         token,
         buffers,
         %{tags: [{{:block_open, name, attrs, meta}, ctx} | tags]} = state
       ) do
    validate_sub_block!(token, name)

    # pop the current buffer and use it as children for the :default sub-block node
    [buffer | buffers] = buffers

    context = state.translator.context_for_subblock(state, :default, ctx, meta)

    {state, node} =
      state.translator.handle_subblock(state, context, :default, [], Enum.reverse(buffer), meta)

    # create a new buffer for the parent node to replace the one that was popped
    buffers = [[] | buffers]
    buffers = push_node_to_current_buffer(node, buffers)

    # push back the parent token to state
    meta = Map.put(meta, :has_sub_blocks?, true)
    state = %{state | tags: [{{:block_open, name, attrs, meta}, ctx} | tags]}

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

  defp push_node_to_current_buffer(:ignore, buffers) do
    buffers
  end

  defp push_node_to_current_buffer(node, buffers) do
    [buffer | buffers] = buffers
    buffer = [node | buffer]
    [buffer | buffers]
  end

  defp translate_attrs(state, context, attrs),
    do: Enum.map(attrs, &translate_attr(state, context, &1))

  defp translate_attr(state, context, {name, {:string, value, %{delimiter: ?"}}, meta}) do
    state.translator.handle_attribute(state, context, name, value, meta)
  end

  defp translate_attr(state, context, {name, {:string, "true", %{delimiter: nil}}, meta}) do
    meta = Map.put(meta, :unquoted_string?, true)
    state.translator.handle_attribute(state, context, name, true, meta)
  end

  defp translate_attr(state, context, {name, {:string, "false", %{delimiter: nil}}, meta}) do
    meta = Map.put(meta, :unquoted_string?, true)
    state.translator.handle_attribute(state, context, name, false, meta)
  end

  defp translate_attr(state, context, {name, {:string, value, %{delimiter: nil}}, meta}) do
    meta = Map.put(meta, :unquoted_string?, true)

    case Integer.parse(value) do
      {int_value, ""} ->
        state.translator.handle_attribute(state, context, name, int_value, meta)

      _ ->
        raise parse_error("unexpected value for attribute \"#{name}\"", meta)
    end
  end

  defp translate_attr(state, context, {:root, {:expr, value, expr_meta}, _attr_meta}) do
    state.translator.handle_attribute(state, context, :root, {:expr, value, expr_meta}, expr_meta)
  end

  defp translate_attr(state, context, {name, {:expr, value, expr_meta}, attr_meta}) do
    state.translator.handle_attribute(state, context, name, {:expr, value, expr_meta}, attr_meta)
  end

  defp translate_attr(state, context, {name, nil, meta}) do
    state.translator.handle_attribute(state, context, name, true, meta)
  end

  defp push_tag(state, {:tag_open, _tag, _attrs, %{void_tag?: true}}, _context) do
    state
  end

  defp push_tag(state, token, context) do
    %{state | tags: [{token, context} | state.tags]}
  end

  defp pop_matching_tag(
         %{tags: [{{:tag_open, tag_name, _, _} = tag, context}| tags]} = state,
         {:tag_close, tag_name, _}
       ) do
    {tag, context, %{state | tags: tags}}
  end

  defp pop_matching_tag(
         %{tags: [{{:block_open, name, _, _} = tag, context} | tags]} = state,
         {:block_close, name, _}
       ) do
    {tag, context, %{state | tags: tags}}
  end

  defp pop_matching_tag(%{tags: [{{_, _, _, meta} = token_open, _ctx} | _]}, token_close) do
    message = """
    expected closing node for #{format_node(token_open)} defined on line #{meta.line}, \
    got #{format_node(token_close)}\
    """

    raise parse_error(message, meta)
  end

  defp parent_context([{_tag, context} | _]), do: context
  defp parent_context([]), do: nil

  def parse_error(message, meta) do
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
