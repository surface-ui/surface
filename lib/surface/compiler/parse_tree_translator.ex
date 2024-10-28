defmodule Surface.Compiler.ParseTreeTranslator do
  @moduledoc false
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.IOHelper
  alias Surface.Compiler.Helpers

  def handle_init(state), do: state

  def handle_expression(expression, meta, state) do
    {{:expr, expression, to_meta(meta)}, state}
  end

  def handle_tagged_expression("^", expression, meta, state) do
    {{:ast, expression, to_meta(meta)}, state}
  end

  def handle_comment(comment, meta, state) do
    {{:comment, comment, meta}, state}
  end

  def handle_node(<<first, _::binary>> = name, attributes, body, meta, state, _context)
      when first == ?. or first in ?A..?Z do
    decomposed_tag = Helpers.decompose_component_tag(name, state.caller)
    meta = Map.put(meta, :decomposed_tag, decomposed_tag)

    {{name, attributes, body, to_meta(meta)}, state}
  end

  def handle_node(name, attributes, body, meta, state, _context) do
    {{name, attributes, body, to_meta(meta)}, state}
  end

  def handle_block(name, [], _body, meta, _state, _context) do
    message = "missing expression for block {\##{name} ...}"
    IOHelper.compile_error(message, meta.file, meta.line)
  end

  def handle_block(name, expr, body, meta, state, _context) do
    {{:block, name, expr, body, to_meta(meta)}, state}
  end

  def handle_subblock(:default, expr, children, meta, state, %{parent_block: "case"}) do
    if !Helpers.blank?(children) do
      message = "cannot have content between {#case ...} and {#match ...}"
      IOHelper.compile_error(message, meta.file, meta.line)
    end

    {{:block, :default, expr, [], to_meta(meta)}, state}
  end

  def handle_subblock(:default, expr, children, meta, state, _context) do
    {{:block, :default, expr, children, to_meta(meta)}, state}
  end

  def handle_subblock(name, expr, children, meta, state, _context) do
    {{:block, name, expr, children, to_meta(meta)}, state}
  end

  def handle_text(text, state) do
    {text, state}
  end

  # TODO: Update these after accepting the expression directly instead of the :root attribute
  def handle_block_expression(_block_name, nil, _state, _context) do
    []
  end

  def handle_block_expression(_block_name, {:expr, expr, expr_meta}, _state, _context) do
    meta = to_meta(expr_meta)
    [{:root, {:attribute_expr, expr, meta}, meta}]
  end

  def handle_attribute(
        :root,
        {:tagged_expr, "...", expr, _marker_meta},
        attr_meta,
        _state,
        context
      ) do
    {:expr, value, expr_meta} = expr
    %{tag_name: tag_name} = context

    directive =
      case tag_name do
        "#slot" ->
          message = """
          cannot pass dynamic attributes to <#slot>.

          Slots only accept the root prop, `for`, `name`, `index`, `generator_value`, `:if` and `:for`.
          """

          IOHelper.compile_error(message, attr_meta.file, attr_meta.line)

        <<first, _::binary>> when first == ?. or first in ?A..?Z ->
          ":props"

        _ ->
          ":attrs"
      end

    {directive, {:attribute_expr, value, to_meta(expr_meta)}, to_meta(attr_meta)}
  end

  def handle_attribute(
        name,
        {:tagged_expr, "...", expr, marker_meta},
        _attr_meta,
        _state,
        _context
      ) do
    value =
      case expr do
        {:expr, value, _expr_meta} -> value
        nil -> ""
      end

    message = """
    cannot assign `{...#{value}}` to attribute `#{name}`. \
    The tagged expression `{... }` can only be used on a root attribute/property.

    Example: <div {...@attrs}>
    """

    IOHelper.compile_error(message, marker_meta.file, marker_meta.line)
  end

  def handle_attribute(
        :root,
        {:tagged_expr, "=", expr, _marker_meta},
        attr_meta,
        _state,
        context
      ) do
    {:expr, value, expr_meta} = expr
    %{tag_name: tag_name} = context

    original_name = strip_name_from_tagged_expr_equals!(value, expr_meta)

    name =
      case tag_name do
        <<first, _::binary>> when first == ?. or first in ?A..?Z ->
          original_name

        _ ->
          String.replace(original_name, "_", "-")
      end

    {name, {:attribute_expr, value, to_meta(expr_meta)}, to_meta(attr_meta)}
  end

  def handle_attribute(
        name,
        {:tagged_expr, "=", expr, marker_meta},
        _attr_meta,
        _state,
        _context
      ) do
    {:expr, value, _expr_meta} = expr

    message = """
    cannot assign `{=#{value}}` to attribute `#{name}`. \
    The tagged expression `{= }` can only be used on a root attribute/property.

    Example: <div {=@class}>
    """

    IOHelper.compile_error(message, marker_meta.file, marker_meta.line)
  end

  def handle_attribute(
        name,
        {:tagged_expr, "^", {:expr, value, expr_meta}, _marker_meta},
        attr_meta,
        _state,
        _context
      ) do
    {name, {:ast, value, to_meta(expr_meta)}, to_meta(attr_meta)}
  end

  def handle_attribute(name, {:expr, expr, expr_meta}, attr_meta, _state, _context) do
    {name, {:attribute_expr, expr, to_meta(expr_meta)}, to_meta(attr_meta)}
  end

  def handle_attribute(name, value, attr_meta, _state, _context) do
    {name, value, to_meta(attr_meta)}
  end

  def context_for_node(name, _meta, _state) do
    %{tag_name: name}
  end

  def context_for_subblock(name, _meta, _state, parent_context) do
    %{sub_block: name, parent_block: Map.get(parent_context, :block_name)}
  end

  def context_for_block(name, _meta, _state) do
    %{block_name: name}
  end

  def to_meta(%{void_tag?: true} = meta) do
    drop_common_keys(meta)
  end

  def to_meta(meta) do
    meta
    |> Map.drop([:void_tag?])
    |> drop_common_keys()
  end

  defp drop_common_keys(meta) do
    Map.drop(meta, [
      :self_close,
      :line_end,
      :column_end,
      :node_line_end,
      :node_column_end,
      :macro?,
      :ignored_body?
    ])
  end

  defp strip_name_from_tagged_expr_equals!(value, expr_meta) do
    case Code.string_to_quoted(value) do
      {:ok, {:@, _, [{name, _, _}]}} when is_atom(name) ->
        to_string(name)

      {:ok, {name, _, _}} when is_atom(name) ->
        to_string(name)

      _ ->
        message = """
        invalid value for tagged expression `{=#{value}}`. \
        The expression must be either an assign or a variable.

        Examples: `<div {=@class}>` or `<div {=class}>`
        """

        IOHelper.compile_error(message, expr_meta.file, expr_meta.line)
    end
  end
end
