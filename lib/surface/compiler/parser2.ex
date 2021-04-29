defmodule Surface.Compiler.Parser2 do
  @moduledoc false

  alias Surface.Compiler.Tokenizer
  alias Surface.Compiler.Tokenizer.ParseError

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

  def parse(code) do
    try do
      tokens = Tokenizer.tokenize(code)
      case to_ast(tokens) do
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

  defp to_ast(tokens) do
    to_ast(tokens, [[]], %{tags: []})
  end

  defp to_ast([], [buffer], _state) do
    Enum.reverse(buffer)
  end

  defp to_ast([], _buffers, %{tags: [{:tag_open, tag_name, _attrs, %{line: line}} | _]}) do
    {:error, "expected closing tag for <#{tag_name}>", line}
  end

  defp to_ast([{:text, text} | rest], buffers, state) do
    buffers = push_node_to_current_buffer(text, buffers)
    to_ast(rest, buffers, state)
  end

  defp to_ast([{:comment, comment} | rest], buffers, state) do
    buffers = push_node_to_current_buffer({:comment, comment}, buffers)
    to_ast(rest, buffers, state)
  end

  defp to_ast([{:interpolation, expr, %{line: line}} | rest], buffers, state) do
    buffers = push_node_to_current_buffer({:interpolation, expr, %{line: line}}, buffers)
    to_ast(rest, buffers, state)
  end

  defp to_ast([{:tag_open, name, attrs, %{line: line}} | rest], buffers, state) when name in @void_elements do
    node = {name, transtate_attrs(attrs), [], %{line: line}}
    buffers = push_node_to_current_buffer(node, buffers)
    to_ast(rest, buffers, state)
  end

  defp to_ast([{:tag_open, name, attrs, %{self_close: true, line: line}} | rest], buffers, state) do
    node = {name, transtate_attrs(attrs), [], %{line: line}}
    buffers = push_node_to_current_buffer(node, buffers)
    to_ast(rest, buffers, state)
  end

  defp to_ast([{:tag_open, _name, _attrs, _meta} = token | rest], buffers, state) do
    state = push_tag(state, token)
    # create a new buffer
    buffers = [[] | buffers]
    to_ast(rest, buffers, state)
  end

  defp to_ast([{:tag_close, name, _meta} | rest], buffers, state) do
    case pop_tag(state, name) do
      {:ok, {{:tag_open, _name, attrs, %{line: line}}, state}} ->
        # pop the current buffer and use it as children for the tag node
        [buffer | buffers] = buffers
        node = {name, transtate_attrs(attrs), Enum.reverse(buffer), %{line: line}}
        buffers = push_node_to_current_buffer(node, buffers)
        to_ast(rest, buffers, state)

      error ->
        error
    end
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

  defp pop_tag(%{tags: [{:tag_open, tag_name, _attrs, _meta} = tag | tags]} = state, tag_name) do
    {:ok, {tag, %{state | tags: tags}}}
  end

  defp pop_tag(%{tags: [{:tag_open, tag_name, _attrs, %{line: line}} | _]}, _) do
    # TODO: change message to "expected closing tag for <bar> defined at line 4, got </foo>"
    {:error, "expected closing tag for <#{tag_name}>", line}
  end
end
