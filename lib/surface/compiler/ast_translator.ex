defmodule Surface.Compiler.AstTranslator do
  @behaviour Surface.Compiler.NodeTranslator

  alias Surface.IOHelper
  alias Surface.AST
  alias Surface.Compiler.Helpers

  def handle_comment(_state, _comment), do: :ignore

  def handle_text(_state, text) do
    %AST.Literal{value: text}
  end

  def handle_end(_state, children) do
    children
  end

  def handle_interpolation(state, expression, parse_meta) do
    ast_meta = to_meta(state, parse_meta)

    %AST.Interpolation{
      original: expression,
      value: Helpers.interpolation_to_quoted!(expression, ast_meta),
      meta: ast_meta
    }
  end

  def context_for_node(_state, name, meta) do

  end

  def handle_attribute(state, context, name, {:expr, value, expr_meta}, attr_meta) do
    %AST.Attribute{
      name: name,
      value: value
    }
  end

  def handle_attribute(state, context, name, value, meta) do
    %AST.Attribute{
      name: name,
      value: value
    }
  end

  def handle_node(state, "template", attributes, body, meta) do
    if warning_enabled?(state, :deprecation_notice) do
      message = """
      using <template> to fill slots has been deprecated and will be removed in \
      future versions.

      Hint: replace `<template>` with `<#template>`
      """

      IOHelper.warn(message, state.caller, fn _ -> meta.line end)
    end

    handle_node(state, "#template", attributes, body, meta)
  end

  def handle_node(state, "slot", attributes, body, meta) do
    if warning_enabled?(state, :deprecation_notice) do
      message = """
      using <slot> to define component slots has been deprecated and will be removed in \
      future versions.

      Hint: replace `<slot>` with `<#slot>`
      """

      IOHelper.warn(message, state.caller, fn _ -> meta.line end)
    end

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
    # %AST.Component{
    #   name: name,
    #   attributes: attributes,
    #   body: block.body,
    #   sub_blocks: sub_blocks,
    #   meta: to_meta(state, meta)
    # }
    nil
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
      checks: state.checks
    }
  end

  defp warning_enabled?(state, warning) do
    Keyword.get(state.warnings, warning, true)
  end
end
