defmodule Surface.Compiler.ParseError do
  defexception file: "nofile", line: 0, column: 1, message: "error parsing HTML/Surface"

  @impl true
  def message(exception) do
    location =
      exception.file
      |> Path.relative_to_cwd()
      |> Exception.format_file_line_column(exception.line, exception.column)

    "#{location} #{exception.message}"
  end
end
