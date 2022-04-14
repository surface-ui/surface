defmodule Mix.Tasks.Compile.Surface do
  @moduledoc """
  Generate CSS and JS/TS assets for components.
  """

  use Mix.Task
  @recursive true

  alias Mix.Task.Compiler.Diagnostic

  @switches [
    return_errors: :boolean,
    warnings_as_errors: :boolean
  ]

  @doc false
  def run(args) do
    {compile_opts, _argv, _err} = OptionParser.parse(args, strict: @switches)

    [
      Mix.Tasks.Compile.Surface.ValidateComponents.validate(project_modules()),
      Mix.Tasks.Compile.Surface.AssetGenerator.run()
    ]
    |> List.flatten()
    |> handle_diagnostics(compile_opts)
  end

  @doc false
  def handle_diagnostics(diagnostics, compile_opts) do
    case diagnostics do
      [] ->
        {:noop, []}

      diagnostics ->
        if !compile_opts[:return_errors], do: print_diagnostics(diagnostics)
        status = status(compile_opts[:warnings_as_errors], diagnostics)

        {status, diagnostics}
    end
  end

  def project_modules do
    files = Mix.Project.compile_path() |> File.ls!() |> Enum.sort()

    for file <- files, [basename, ""] <- [:binary.split(file, ".beam")] do
      String.to_atom(basename)
    end
  end

  defp print_diagnostics(diagnostics) do
    for %Diagnostic{message: message, severity: severity, file: file, position: position} <- diagnostics do
      print_diagnostic(message, severity, file, position)
    end
  end

  defp print_diagnostic(message, :warning, _file, _line), do: IO.warn(message, [])

  defp print_diagnostic(message, :error, file, line) do
    error = IO.ANSI.format([:red, "error: "])

    stacktrace =
      "  #{file}" <>
        if(line, do: ":#{line}", else: "")

    IO.puts(:stderr, [error, message, ?\n, stacktrace])
  end

  defp status(warnings_as_errors, diagnostics) do
    cond do
      Enum.any?(diagnostics, &(&1.severity == :error)) -> :error
      warnings_as_errors && Enum.any?(diagnostics, &(&1.severity == :warning)) -> :error
      true -> :ok
    end
  end
end
