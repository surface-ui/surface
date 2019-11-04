defmodule Surface.Translator.ComponentTranslator do
  @callback translate(mod :: any, mod_str :: any, attributes :: any, directives :: any,
            children :: any, children_groups_contents :: any, caller :: any) :: iolist

  def add_render_call(renderer, args, has_children?) do
    ["<%= ", renderer, "(",  Enum.join(args, ", "), ") ", maybe_add("do ", has_children?), "%>"]
  end

  def maybe_add(value, condition) do
    if condition, do: value, else: ""
  end

  def maybe_add_context_begin(mod, mod_str, rendered_props) do
    if function_exported?(mod, :begin_context, 1) do
      ["<% context = ", mod_str, ".begin_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end

  def maybe_add_context_end(mod, mod_str, rendered_props) do
    if function_exported?(mod, :end_context, 1) do
      ["<% context = ", mod_str, ".end_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end
end
