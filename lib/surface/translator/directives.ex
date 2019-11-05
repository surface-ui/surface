# TODO:
# 1- See if it's better to create a protocol for this
# 2- Do not apply all directives to all nodes (e.g. :bindings only applies to components)
defmodule Surface.Translator.Directive do

  @directives [":for", ":bindings"]

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

  # TODO: Find another way to do this wihout passing the last boolean arg
  def code_after_begin({":bindings", {:attribute_expr, [expr]}, _line}, true) do
    ["<% ", String.trim(expr), " -> %>"]
  end

  def code_after_begin({":bindings", _value, _line}, _) do
    []
  end

  def code_after_begin(_, _) do
    []
  end

  def pop_directives(attributes) do
    Enum.split_with(attributes, fn {attr, _, _} -> attr in @directives end)
  end

  def maybe_add_directives_begin(attributes) do
    for attr <- attributes, code = code_begin(attr), code != [] do
      code
    end
  end

  def maybe_add_directives_after_begin(attributes, using_live_view?) do
    for attr <- attributes, code = code_after_begin(attr, using_live_view?), code != [] do
      code
    end
  end

  def maybe_add_directives_end(attributes) do
    for attr <- attributes, code = code_end(attr), code != [] do
      code
    end
  end
end
