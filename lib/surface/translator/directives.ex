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
end
