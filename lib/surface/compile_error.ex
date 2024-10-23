defmodule Surface.CompileError do
  @moduledoc """
  An exception raised when there's a Surface compile error.

  The following fields of this exceptions are public and can be accessed freely:

    * `:file` (`t:Path.t/0` or `nil`) - the file where the error occurred, or `nil` if
      the error occurred in code that did not come from a file
    * `:line` - the line where the error occurred
    * `:column` - the column where the error occurred
    * `:description` - a description of the error
    * `:hint` - a hint to help the user to fix the issue

  """

  @support_snippet Version.match?(System.version(), ">= 1.17.0")

  defexception [:file, :line, :column, :snippet, :hint, description: "compile error"]

  @impl true
  def message(%{
        file: file,
        line: line,
        column: column,
        description: description,
        hint: hint
      }) do
    format_message(file, line, column, description, hint)
  end

  if @support_snippet do
    defp format_message(file, line, column, description, hint) do
      message =
        if File.exists?(file) do
          {lineCode, _} = File.stream!(file) |> Stream.with_index() |> Enum.at(line - 1)
          lineCode = String.trim_trailing(lineCode)
          :elixir_errors.format_snippet(:error, {line, column}, file, description, lineCode, %{})
        else
          description
        end

      hint =
        if hint do
          "\n\n" <> :elixir_errors.format_snippet(:hint, nil, nil, hint, nil, %{})
        else
          ""
        end

      location = Exception.format_file_line_column(Path.relative_to_cwd(file), line, column)
      location <> " " <> message <> hint
    end
  else
    defp format_message(file, line, column, description, hint) do
      location = Exception.format_file_line_column(Path.relative_to_cwd(file), line, column)
      location <> " " <> description <> (hint || "")
    end
  end
end
