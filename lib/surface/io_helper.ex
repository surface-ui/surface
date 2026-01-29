defmodule Surface.IOHelper do
  @moduledoc false

  def warn(message, caller) do
    stacktrace = Macro.Env.stacktrace(caller)

    IO.warn(message, stacktrace)
  end

  def warn(message, caller, line) do
    stacktrace = Macro.Env.stacktrace(%{caller | line: line})

    IO.warn(message, stacktrace)
  end

  def warn(message, _caller, file, {line, column}) do
    IO.warn(message, file: file, line: line, column: column)
  end

  def warn(message, caller, file, line) do
    stacktrace = Macro.Env.stacktrace(%{caller | file: file, line: line})

    IO.warn(message, stacktrace)
  end

  def compile_error(message, file, {line, column}) do
    reraise(%Surface.CompileError{file: file, line: line, column: column, description: message}, [])
  end

  def compile_error(message, file, line) do
    reraise(%Surface.CompileError{line: line, file: file, description: message}, [])
  end

  def compile_error(message, hint, file, {line, column}) do
    reraise(%Surface.CompileError{file: file, line: line, column: column, description: message, hint: hint}, [])
  end

  def compile_error(message, hint, file, line) do
    reraise(%Surface.CompileError{line: line, file: file, description: message, hint: hint}, [])
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
end
