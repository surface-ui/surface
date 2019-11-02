# TODO:
# 1- See if it's better to create a protocol for this
# 2- Do not apply all directives to all nodes (e.g. :bindings only applies to conmponents)
defmodule Surface.Translator.Directive do
  def code_begin({":for", {:attribute_expr, [expr]}, _line}) do
    ["<%= for ", String.trim(expr), " do %>"]
  end

  def code_begin(_) do
    []
  end

  def code_end({":for", _value, _line}) do
    "<% end %>"
  end

  def code_end(_) do
    []
  end

  def code_after_begin({":bindings", {:attribute_expr, [expr]}, _line}) do
    ["<% ", String.trim(expr), " -> %>"]
  end

  def code_after_begin(_) do
    []
  end
end
