defmodule Surface.Compiler.ParseTreeTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.IOHelper

  def handle_init(state), do: state

  def handle_expression(state, expression, meta) do
    {state, {:expr, expression, to_meta(meta)}}
  end

  def handle_comment(state, comment, meta) do
    {state, {:comment, comment, meta}}
  end

  def handle_node(state, context, "template", attributes, body, meta) do
    message = """
    using <template> to fill slots has been deprecated and will be removed in \
    future versions.

    Hint: replace `<template>` with `<#template>`
    """

    IOHelper.warn(message, state.caller, fn _ -> meta.line end)

    handle_node(state, context, "#template", attributes, body, meta)
  end

  def handle_node(state, context, "slot", attributes, body, meta) do
    message = """
    using <slot> to define component slots has been deprecated and will be removed in \
    future versions.

    Hint: replace `<slot>` with `<#slot>`
    """

    IOHelper.warn(message, state.caller, fn _ -> meta.line end)
    handle_node(state, context, "#slot", attributes, body, meta)
  end

  def handle_node(state, _context, name, attributes, body, meta) do
    {state, {name, attributes, body, to_meta(meta)}}
  end

  def handle_block(state, context, name, expr, body, meta) do
    attrs = block_expr_to_attr_list(expr, state, context)
    {state, {:block, name, attrs, body, to_meta(meta)}}
  end

  def handle_subblock(state, context, :default, expr, children, _meta) do
    attrs = block_expr_to_attr_list(expr, state, context)
    {state, {:block, :default, attrs, children, %{}}}
  end

  def handle_subblock(state, context, name, expr, children, meta) do
    attrs = block_expr_to_attr_list(expr, state, context)
    {state, {:block, name, attrs, children, to_meta(meta)}}
  end

  def handle_text(state, text) do
    {state, text}
  end

  def handle_attribute(_state, _context, name, {:expr, expr, expr_meta}, attr_meta) do
    {name, {:attribute_expr, expr, to_meta(expr_meta)}, to_meta(attr_meta)}
  end

  def handle_attribute(_state, _context, name, value, attr_meta) do
    {name, value, to_meta(attr_meta)}
  end

  def context_for_node(_state, _name, _meta) do
    nil
  end

  def context_for_subblock(_state, _name, _parent_name, _meta) do
    nil
  end

  def context_for_block(_state, _name, _meta) do
    nil
  end

  def to_meta(%{void_tag?: true} = meta) do
    Map.drop(meta, [:self_close, :line_end, :column_end])
  end

  def to_meta(meta) do
    Map.drop(meta, [:self_close, :line_end, :column_end, :void_tag?])
  end

  # TODO: Update these after accepting the expression directly instead of the :root attribute
  defp block_expr_to_attr_list(nil, _state, _context), do: []

  defp block_expr_to_attr_list({:expr, _, expr_meta} = expr, state, context) do
    [handle_attribute(state, context, :root, expr, expr_meta)]
  end
end
