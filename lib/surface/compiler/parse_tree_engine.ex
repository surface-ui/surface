defmodule Surface.Compiler.ParseTreeEngine do
  @behaviour Surface.Compiler.Engine

  alias Surface.IOHelper

  def handle_interpolation(_state, expression, meta) do
    {:interpolation, expression, meta}
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
    {name, attributes, body, meta}
  end

  def handle_subblock(_state, name, attrs, children, meta) do
    {name, attrs, children, meta}
  end

  def handle_text(_state, text) do
    text
  end

  def handle_end(_state, children) do
    children
  end
end
