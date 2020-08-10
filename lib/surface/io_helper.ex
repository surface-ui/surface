defmodule Surface.IOHelper do
  @moduledoc false

  def warn(message, caller, update_line_fun) do
    stacktrace =
      caller
      |> Macro.Env.stacktrace()
      |> update_line(update_line_fun)

    IO.warn(message, stacktrace)
  end

  @spec compile_error(String.t(), String.t(), integer()) :: no_return()
  def compile_error(message, file, line) do
    reraise(%CompileError{line: line, file: file, description: message}, [])
  end

  @spec syntax_error(String.t(), String.t(), integer()) :: no_return()
  def syntax_error(message, file, line) do
    reraise(%SyntaxError{line: line, file: file, description: message}, [])
  end

  @spec runtime_error(String.t()) :: no_return()
  def runtime_error(message) do
    stacktrace =
      self()
      |> Process.info(:current_stacktrace)
      |> elem(1)
      |> Enum.drop(2)

    reraise(message, stacktrace)
  end

  defp update_line([{a, b, c, [d, {:line, line}]}], fun) do
    [{a, b, c, [d, {:line, fun.(line)}]}]
  end
end
