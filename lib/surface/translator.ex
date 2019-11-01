defmodule Surface.Translator do
  alias Surface.Translator.{Parser, Directive, NodeTranslator}

  @directives [":for"]

  def run(string, line_offset, caller) do
    string
    |> Parser.parse(line_offset)
    |> Surface.TranslatorUtils.put_module_info(caller)
    |> prepend_context()
    |> NodeTranslator.translate(caller)
    |> IO.iodata_to_binary()
  end

  defp prepend_context(parsed_code) do
    ["<% context = %{} %><% _ = context %>" | parsed_code]
  end

  def maybe_add_directives_begin(attributes) do
    for attr <- attributes, code = Directive.code_begin(attr), code != [] do
      code
    end
  end

  def maybe_add_directives_end(attributes) do
    for attr <- attributes, code = Directive.code_end(attr), code != [] do
      code
    end
  end

  def pop_directives(attributes) do
    Enum.split_with(attributes, fn {attr, _, _} -> attr in @directives end)
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

  def debug(iolist, props, line, caller) do
    if Enum.find(props, fn {k, v, _} -> k in ["debug", :debug] && v end) do
      IO.puts ">>> DEBUG: #{caller.file}:#{caller.line + line}"
      iolist
      |> IO.iodata_to_binary()
      |> IO.puts
      IO.puts "<<<"
    end
    iolist
  end
end
