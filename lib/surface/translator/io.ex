defmodule Surface.Translator.IOHelper do
  @moduledoc false

  def warn(message, caller, update_line_fun) do
    stacktrace =
      caller
      |> Macro.Env.stacktrace()
      |> udpate_line(update_line_fun)

    IO.warn(message, stacktrace)
  end

  def compile_error(message, file, line) do
    reraise(%CompileError{line: line, file: file, description: message}, [])
  end

  defp udpate_line([{a, b, c, [d, {:line, line}]}], fun) do
    [{a, b, c, [d, {:line, fun.(line)}]}]
  end
end
