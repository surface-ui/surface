defmodule Surface.Translator.ComponentTranslator do
  @callback translate(mod :: any, mod_str :: any, attributes :: any, directives :: any,
    children :: any, children_groups_contents :: any, has_children? :: boolean,
    caller :: any) :: iolist

  def add_render_call(renderer, args, has_children?) do
    ["<%= ", renderer, "(",  Enum.join(args, ", "), ") ", maybe_add("do ", has_children?), "%>"]
  end

  def maybe_add(value, condition) do
    if condition, do: value, else: ""
  end

  def maybe_add_begin_context(mod, mod_str, rendered_props) do
    if function_exported?(mod, :begin_context, 1) do
      ["<% context = ", mod_str, ".begin_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end

  def maybe_add_end_context(mod, mod_str, rendered_props) do
    if function_exported?(mod, :end_context, 1) do
      ["<% context = ", mod_str, ".end_context(", rendered_props, ") %><% _ = context %>"]
    else
      ""
    end
  end

  # TODO: Remove
  def maybe_add_begin_lazy_content([]) do
    ""
  end

  def maybe_add_begin_lazy_content(bindings) do
    ["<%= lazy fn ", Enum.join(bindings, ", "), " -> %>"]
  end

  def maybe_add_end_lazy_content([]) do
    ""
  end

  def maybe_add_end_lazy_content(_bindings) do
    ["<% end %>"]
  end
end
