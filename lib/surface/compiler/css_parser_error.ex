defmodule Surface.Compiler.CSSParserError do
  defexception [:file, :line, :column, :message]

  @impl true
  def message(exception) do
    location =
      exception.file
      |> Path.relative_to_cwd()
      |> Exception.format_file_line_column(exception.line, exception.column)

    "#{location} #{exception.message}"
  end
end
