defmodule Surface.Compiler.ParseTreeTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.IOHelper

  def handle_interpolation(_state, expression, meta) do
    {:interpolation, expression, to_meta(meta)}
  end

  def handle_comment(_state, comment) do
    {:comment, comment}
  end

  def handle_node(state, "template", attributes, body, meta) do
    message = """
    using <template> to fill slots has been deprecated and will be removed in \
    future versions.

    Hint: replace `<template>` with `<#template>`
    """

    IOHelper.warn(message, state.caller, fn _ -> meta.line end)

    handle_node(state, "#template", attributes, body, meta)
  end

  def handle_node(state, "slot", attributes, body, meta) do
    message = """
    using <slot> to define component slots has been deprecated and will be removed in \
    future versions.

    Hint: replace `<slot>` with `<#slot>`
    """

    IOHelper.warn(message, state.caller, fn _ -> meta.line end)
    handle_node(state, "#slot", attributes, body, meta)
  end

  def handle_node(_state, name, attributes, body, meta) do
    {name, attributes, body, to_meta(meta)}
  end

  def handle_subblock(_state, name, attrs, children, meta) do
    {name, attrs, children, to_meta(meta)}
  end

  def handle_literal(_state, text) do
    text
  end

  def handle_end(_state, children) do
    children
  end

  def handle_attribute_expression(_state, value, meta) do
    {:attribute_expr, value, to_meta(meta)}
  end

  def handle_attribute(_state, name, value, meta) do
    {name, value, to_meta(meta)}
  end

  def to_meta(%{void_tag?: true} = meta) do
    Map.drop(meta, [:self_close, :line_end, :column_end])
  end

  def to_meta(meta) do
    Map.drop(meta, [:self_close, :line_end, :column_end, :void_tag?])
  end
end
