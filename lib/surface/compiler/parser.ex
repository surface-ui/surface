defmodule Surface.Compiler.Parser do
  @moduledoc false

  alias Surface.Compiler.Tokenizer
  alias Surface.Compiler.ParseError
  alias Surface.Compiler.Helpers
  alias Surface.IOHelper

  @type state :: %{
          token_stack:
            list({Tokenizer.block_open() | Tokenizer.tag_open(), Surface.Compiler.NodeTranslator.context()}),
          translator: module(),
          caller: Macro.Env.t(),
          checks: keyword(boolean()),
          warnings: keyword(boolean())
        }

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
      token_stack: [],
      caller: opts[:caller] || __ENV__,
      checks: opts[:checks] || [],
      warnings: opts[:warnings] || []
    }

    handle_token(tokens, [[]], state.translator.handle_init(state))
  end

  defp handle_token([], [buffer], _state) do
    Enum.reverse(buffer)
  end

  defp handle_token([], _buffers, %{token_stack: [{{_, _name, _attrs, meta} = node, _ctx} | _]}) do
    message = "end of file reached without closing #{node_type(node)} for #{format_node(node)}"
    raise parse_error(message, meta)
  end

  defp handle_token([{:text, text} | rest], buffers, state) do
    {node, state} = state.translator.handle_text(text, state)
    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:comment, comment, meta} | rest], buffers, state) do
    {node, state} = state.translator.handle_comment(comment, meta, state)

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:expr, expr, meta} | rest], buffers, state) do
    {node, state} = state.translator.handle_expression(expr, meta, state)

    buffers = push_node_to_current_buffer(node, buffers)

    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tagged_expr, marker, {:expr, value, meta}, _marker_meta} | rest], buffers, state) do
    {node, state} = state.translator.handle_tagged_expression(marker, value, meta, state)

    buffers = push_node_to_current_buffer(node, buffers)

    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, %{void_tag?: true} = meta} | rest], buffers, state) do
    context = state.translator.context_for_node(name, meta, state)

    {node, state} =
      state.translator.handle_node(name, translate_attrs(state, context, attrs), [], meta, state, context)

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, attrs, %{self_close: true} = meta} | rest], buffers, state) do
    context = state.translator.context_for_node(name, meta, state)

    {node, state} =
      state.translator.handle_node(name, translate_attrs(state, context, attrs), [], meta, state, context)

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_open, name, _attrs, meta} = token | rest], buffers, state) do
    context = state.translator.context_for_node(name, meta, state)
    state = push_tag(state, token, context)
    # create a new buffer for the node
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:tag_close, name, _meta} = token | rest], buffers, state) do
    {{:tag_open, _name, attrs, meta}, context, state} = pop_matching_tag(state, token)

    # pop the current buffer and use it as children for the node
    [buffer | buffers] = buffers

    translated_attrs = translate_attrs(state, context, attrs)

    {node, state} =
      state.translator.handle_node(name, translated_attrs, Enum.reverse(buffer), meta, state, context)

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_open, name, expr, meta} = token | rest], buffers, state) when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)

    context = state.translator.context_for_subblock(name, parent_context(state.token_stack), meta, state)

    # push the current sub-block token to state
    state = push_tag(state, {:block_open, name, expr, meta}, context)

    # create a new buffer for the current sub-block
    buffers = [[] | buffers]

    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_open, name, _expr, meta} = token | rest], buffers, state) when name in @blocks do
    context = state.translator.context_for_block(name, meta, state)

    state = push_tag(state, token, context)
    # create a new buffer for the node
    buffers = [[] | buffers]
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_open, name, _expr, meta} | _], _buffers, _state) do
    blocks = Helpers.list_to_string("block is", "blocks are", @blocks ++ @sub_blocks)
    raise parse_error("unknown `{##{name}}` block. Available #{blocks}", meta)
  end

  defp handle_token(
         [{:block_close, _name, _meta} = token | _] = tokens,
         buffers,
         %{token_stack: [{{:block_open, name, _, _}, _} | _]} = state
       )
       when name in @sub_blocks do
    {buffers, state} = close_sub_block(token, buffers, state)
    handle_token(tokens, buffers, state)
  end

  defp handle_token([{:block_close, name, _meta} = token | rest], buffers, state) when name in @blocks do
    {{:block_open, name, expr, meta}, context, state} = pop_matching_tag(state, token)
    meta = Map.put_new(meta, :has_sub_blocks?, false)

    # pop the current buffer and use it as children for the node
    [buffer | buffers] = buffers

    expression = state.translator.handle_block_expression(name, expr, state, context)

    {node, state} =
      state.translator.handle_block(
        name,
        expression,
        Enum.reverse(buffer),
        meta,
        state,
        context
      )

    buffers = push_node_to_current_buffer(node, buffers)
    handle_token(rest, buffers, state)
  end

  defp handle_token([{:block_close, name, meta} | _], _buffers, _state) do
    blocks = Helpers.list_to_string("block is", "blocks are", @blocks)
    raise parse_error("unknown `{/#{name}}` block. Available #{blocks}", meta)
  end

  # If there's a previous sub-block defined. Close it.
  defp close_sub_block(
         _token,
         buffers,
         %{token_stack: [{{:block_open, name, expr, meta}, context} | tokens]} = state
       )
       when name in @sub_blocks do
    # pop the current buffer and use it as children for the sub-block node
    [buffer | buffers] = buffers

    expression = state.translator.handle_block_expression(name, expr, state, context)

    {node, state} = state.translator.handle_subblock(name, expression, Enum.reverse(buffer), meta, state, context)

    state = %{state | token_stack: tokens}
    buffers = push_node_to_current_buffer(node, buffers)

    {buffers, state}
  end

  # If there's no previous sub-block defined. Create a :default sub-block,
  # move the buffer there and close it.
  defp close_sub_block(
         token,
         buffers,
         %{token_stack: [{{:block_open, name, expr, meta}, ctx} | tokens]} = state
       ) do
    validate_sub_block!(token, name)

    # pop the current buffer and use it as children for the :default sub-block node
    [buffer | buffers] = buffers

    context = state.translator.context_for_subblock(:default, meta, state, ctx)
    expression = state.translator.handle_block_expression(:default, nil, state, context)

    {node, state} =
      state.translator.handle_subblock(:default, expression, Enum.reverse(buffer), meta, state, context)

    # create a new buffer for the parent node to replace the one that was popped
    buffers = [[] | buffers]
    buffers = push_node_to_current_buffer(node, buffers)

    # push back the parent token to state
    meta = Map.put(meta, :has_sub_blocks?, true)
    state = %{state | token_stack: [{{:block_open, name, expr, meta}, ctx} | tokens]}

    {buffers, state}
  end

  # If there's no parent node
  defp close_sub_block({:block_open, name, _expr, meta}, _buffers, _state) do
    message = message_for_invalid_sub_block_parent(name)
    raise parse_error(message, meta)
  end

  defp validate_sub_block!({:block_open, name, _expr, meta}, parent_name) do
    if parent_name not in @sub_blocks_valid_parents[name] do
      message = message_for_invalid_sub_block_parent(name)
      raise parse_error(message, meta)
    end
  end

  defp message_for_invalid_sub_block_parent(name) do
    valid_parents = @sub_blocks_valid_parents[name]
    valid_parents_tokens = Enum.map(valid_parents, &"{##{&1}}")

    "no valid parent node defined for {##{name}}. " <>
      Helpers.list_to_string(
        "The {##{name}} construct can only be used inside a",
        "Possible parents are",
        valid_parents_tokens
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
    state.translator.handle_attribute(name, value, meta, state, context)
  end

  defp translate_attr(state, context, {name, {:string, value, %{delimiter: ?'}}, meta}) do
    state.translator.handle_attribute(name, value, meta, state, context)
  end

  defp translate_attr(state, context, {name, {:string, value, %{delimiter: nil}}, meta}) do
    IOHelper.warn(
      """
      Using unquoted attribute values is not recommended as they will always be converted to strings.

      For instance, `selected=true` and `tabindex=3` will be translated to `selected="true"` and `tabindex="3"` respectively.

      Hint: if you want to pass a literal boolean or integer, replace `#{name}=#{value}` with `#{name}={#{value}}`
      """,
      state.caller,
      meta.file,
      meta.line
    )

    state.translator.handle_attribute(name, value, meta, state, context)
  end

  defp translate_attr(state, context, {:root, {:expr, _value, expr_meta} = expr, _attr_meta}) do
    state.translator.handle_attribute(:root, expr, expr_meta, state, context)
  end

  defp translate_attr(
         state,
         context,
         {:root, {:tagged_expr, _marker, _expr, marker_meta} = expr, _attr_meta}
       ) do
    state.translator.handle_attribute(:root, expr, marker_meta, state, context)
  end

  defp translate_attr(state, context, {name, {:expr, _value, _expr_meta} = expr, attr_meta}) do
    state.translator.handle_attribute(name, expr, attr_meta, state, context)
  end

  defp translate_attr(
         state,
         context,
         {name, {:tagged_expr, _marker, _expr, marker_meta} = expr, _attr_meta}
       ) do
    state.translator.handle_attribute(name, expr, marker_meta, state, context)
  end

  defp translate_attr(state, context, {name, nil, meta}) do
    state.translator.handle_attribute(name, true, meta, state, context)
  end

  defp push_tag(state, {:tag_open, _tag, _attrs, %{void_tag?: true}}, _context) do
    state
  end

  defp push_tag(state, token, context) do
    %{state | token_stack: [{token, context} | state.token_stack]}
  end

  defp pop_matching_tag(
         %{token_stack: [{{:tag_open, tag_name, _, _} = token, context} | tokens]} = state,
         {:tag_close, tag_name, _}
       ) do
    {token, context, %{state | token_stack: tokens}}
  end

  defp pop_matching_tag(
         %{token_stack: [{{:block_open, name, _, _} = token, context} | tokens]} = state,
         {:block_close, name, _}
       ) do
    {token, context, %{state | token_stack: tokens}}
  end

  defp pop_matching_tag(%{token_stack: [{{_, _, _, meta} = token_open, _ctx} | _]}, token_close) do
    {_, _, meta_close} = token_close

    message = """
    expected closing #{node_type(token_open)} for #{format_node(token_open)} defined on line #{meta.line}, \
    got #{format_node(token_close)}\
    """

    raise parse_error(message, meta_close)
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

  defp node_type({:tag_open, _, _, _}), do: "tag"
  defp node_type({:block_open, _, _, _}), do: "block"

  defp format_node({:tag_open, name, _attrs, _meta}), do: "<#{name}>"
  defp format_node({:tag_close, name, _meta}), do: "</#{name}>"
  defp format_node({:block_open, name, _attrs, _meta}), do: "{##{name}}"
  defp format_node({:block_close, name, _meta}), do: "{/#{name}}"
end
