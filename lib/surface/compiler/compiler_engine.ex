defmodule Surface.Compiler.CompilerEngine do
  @behaviour Surface.Compiler.Engine

  alias Surface.IOHelper
  alias Surface.AST
  alias Surface.Compiler.Helpers

  def handle_interpolation(state, expression, parser_meta) do
    ast_meta = to_meta(state, parser_meta)

    %AST.Interpolation{
      original: expression,
      value: Helpers.interpolation_to_quoted!(expression, ast_meta),
      meta: ast_meta
    }
  end

  def handle_comment(_state, comment) do
    # TODO: allow ignoring results
    %AST.Literal{value: comment}
  end

  def handle_text(_state, text) do
    %AST.Literal{value: text}
  end

  def handle_end(_state, children) do
    children
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

  def handle_node(state, <<"#", first, _::binary>> = name, attributes, body, meta)
      when first in ?A..?Z do
        %AST.MacroComponent{
          name: name,
          attributes: attributes,
          body: body,
          meta: to_meta(state, meta)
        }
    {name, attributes, body, meta}
  end

  def handle_node(state, <<"#", first, _::binary>> = name, attributes, [block | sub_blocks], meta)
      when first in ?a..?z do
    %AST.Construct{
      name: name,
      attributes: attributes,
      body: block.body,
      sub_blocks: sub_blocks,
      meta: to_meta(state, meta)
    }
  end

  def handle_node(state, <<first, _::binary>> = name, attributes, [block | sub_blocks], meta)
      when first in ?A..?Z do
    %AST.Component{
      name: name,
      attributes: attributes,
      body: block.body,
      sub_blocks: sub_blocks,
      meta: to_meta(state, meta)
    }
  end

  def handle_subblock(state, name, attrs, children, meta) do
    %AST.Construct.SubBlock{
      name: name,
      # TODO: allow translating attributes ?
      attributes: attrs,
      body: children,
      meta: to_meta(state, meta)
    }
  end

  def to_meta(state, parse_meta) do
    %AST.Meta{
      line: parse_meta.line,
      column: parse_meta.column,
      file: parse_meta.file,
      caller: state.caller,
      checks: []
    }
  end
end
