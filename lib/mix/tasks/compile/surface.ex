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

  * `only_web_namespace` - instructs the compiler to only search for components defined in
    the project's web module namespace, e.g. `MyAppWeb`. Default is `false`.

  ### Example

      config :surface, :compiler,
        hooks_output_dir: "assets/js/surface"
        only_web_namespace: true

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

    Mix.Tasks.Compile.Surface.AssetGenerator.run()
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
    for %Diagnostic{message: message, severity: :warning} <- diagnostics do
      IO.warn(message, [])
    end
  end

  defp status(warnings_as_errors, diagnostics) do
    cond do
      Enum.any?(diagnostics, &(&1.severity == :error)) -> :error
      warnings_as_errors && Enum.any?(diagnostics, &(&1.severity == :warning)) -> :error
      true -> :ok
    end
  end
end
