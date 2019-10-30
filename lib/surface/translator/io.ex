defmodule Surface.Translator.IO do
  def warn(message, caller, update_line_fun) do
    stacktrace =
      Macro.Env.stacktrace(caller)
      |> (fn([{a, b, c, [d, {:line, line}]}]) -> [{a, b, c, [d, {:line, update_line_fun.(line)}]}] end).()
    IO.warn(message, stacktrace)
  end
end
