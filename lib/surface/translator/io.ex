defmodule Surface.Translator.IO do
  def warn(message, caller, update_line_fun) do
    stacktrace =
      Macro.Env.stacktrace(caller)
      |> (fn([{a, b, c, [d, {:line, line}]}]) -> [{a, b, c, [d, {:line, update_line_fun.(line)}]}] end).()
    IO.warn(message, stacktrace)
  end

  # TODO: Create a :debug directive instead of a property and use Logger
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
