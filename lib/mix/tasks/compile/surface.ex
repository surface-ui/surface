defmodule Mix.Tasks.Compile.Surface do
  @moduledoc """
  Generate CSS and JS/TS assets for components.

  ## Setup

  Update `mix.exs`, adding the `:surface` compiler to the list of compilers:

  ```elixir
  def project do
    [
      ...,
      compilers: [:phoenix] ++ Mix.compilers() ++ [:surface]
    ]
  end
  ```

  ## Configuration (optional)

  The Surface compiler provides some options for custom configuration in your `config/dev.exs`.

  ### Options

  * `hooks_output_dir` - defines the folder where the compiler generates the JS hooks files.
    Default is `./assets/js/_hooks/`.

  * `warn_on_undefined_props` - shows warnings when passing assigns that are not defined
    as props on the component. Default is `true`.

  ### Example

      config :surface, :compiler,
        hooks_output_dir: "assets/js/surface",
        warn_on_undefined_props: true
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
    {compile_opts, _argv, _err} = OptionParser.parse(args, switches: @switches)
    opts = Application.get_env(:surface, :compiler, [])
    asset_opts = Keyword.take(opts, [:hooks_output_dir])
    asset_components = Surface.components()
    project_components = Surface.components(only_current_project: true)

    [
      Mix.Tasks.Compile.Surface.ValidateComponents.validate(project_components),
      Mix.Tasks.Compile.Surface.AssetGenerator.run(asset_components, asset_opts)
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

  defp print_diagnostics(diagnostics) do
    for %Diagnostic{message: message, severity: severity, file: file, position: position} <- diagnostics do
      print_diagnostic(message, severity, file, position)
    end
  end

  defp print_diagnostic(message, :warning, file, line) do
    # Use IO.warn(message, file: ..., line: ...) on Elixir v1.14+
    rel_file = file |> Path.relative_to_cwd() |> to_charlist()
    IO.warn(message, [{nil, :__FILE__, 1, [file: rel_file, line: line]}])
  end

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
