defmodule Surface.Compiler.ParseTreeTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.IOHelper

  def handle_init(state), do: state

  def handle_interpolation(state, expression, meta) do
    {state, {:interpolation, expression, to_meta(meta)}}
  end

  def handle_comment(state, comment, _meta) do
    {state, {:comment, comment}}
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

  def handle_block(state, _context, name, attributes, body, meta) do
    {state, {:block, name, attributes, body, to_meta(meta)}}
  end

  def handle_subblock(state, _context, :default, attrs, children, _meta) do
    {state, {:default, attrs, children, %{}}}
  end

  def handle_subblock(state, _context, name, attrs, children, meta) do
    {state, {name, attrs, children, to_meta(meta)}}
  end

  def handle_literal(state, text) do
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
end
