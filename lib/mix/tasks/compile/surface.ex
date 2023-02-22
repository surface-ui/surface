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

  * `css_output_file` - defines the css file where the compiler generates the code.
    Default is `./assets/css/_components.css`.

  * `enable_variants` [experimental] - instructs the compiler to generate tailwind variants based
    on props/data. Currently, only Tailwind variants are supported. Default is `false`.
    See more in the "Enabling CSS variants" section below.

  * `variants_output_file` [experimental] - if `enable_variants` is `true`, defines the config file where
    the compiler generates the scoped variants. Currently, only Tailwind variants are supported.
    Default is `./assets/css/_variants.js`.

  ### Example

      config :surface, :compiler,
        hooks_output_dir: "assets/js/surface",
        css_output_file: "assets/css/surface.css",
        enable_variants: true

  ### Enabling CSS variants

  By setting `enable_variants` to `true`, we instruct the compiler to generate tailwind
  variants based on props/data. All variants are generated in the `variants_output_file`,
  which defaults to `./assets/css/_variants.js`.

  > **NOTE**: This feature is still experimental and available for feedback.
  > Therefore, the API might change in the next Surface minor version. It's also
  > currently only available for Tailwind.

  To make the generated variants available in your templates, you need to set up the
  project's `tailwind.config.js` to add the `variants_output_file` as
  a preset. Example:

      module.exports = {
        presets: [
          require('./css/_variants.js')
        ],
        ...
      }

  ## Defining CSS variants

  In order to define CSS variants for your templates, you can use the `css_variant`
  option, which is available for both, `prop` and `data`.

  ### Example

      prop loading, :boolean, css_variant: true
      prop size, :string, values: ["small", "medium", "large"], css_variant: true

  Depending on the type of the assign you're defining, a set of default variants will
  be automatically available in your tamplates and be used directly in any `class`
  attribute.

  ### Example

      <button class="loading:opacity-75 size-small:text-sm size-medium:text-base size-large:text-lg">
        Submit
      </button>

  ## Customizing variants' names

  Most of the time, you probably want to stick with the default variant naming convension,
  however there are cases when renaming them may be more intuitive. For instance:

      # Use `inactive` instead of `not-active`
      prop active, :boolean, css_variant: [false: "inactive"]

      # Use `valid` and `invalid` instead of `has-errors` and `no-errors`
      data errors, :list, css_variant: [has_items: "invalid", no_items: "valid"]

      # Use `small`, `medium` and `large` instead of `size-small`, `size-medium` and `size-large`
      prop size, :string, values: ["small", "medium", "large"], css_variant: [prefix: ""]

  As you can see, the value of `css_variant` can be either a boolean or a keyword list of options.

  By passing `true`, the compiler generates variants according to the default values
  for each option based to the name and type of the related assign. All available options for each type
  are listed below.

  ### Options for `:boolean`

  * `:true` - the name of the variant when the value is truthy. Default is the assign name.
  * `:false` - the name of the variant when the value is falsy. Default is `not-[assign-name]`.

  ### Options for enumerables, e.g. `:list`, `:map` and `:mapset`

  * `:has_items` - the name of the variant when the value list has items.
    Default is `has-[assign-name]`
  * `:no_items` - the name of the variant when the value is empty or `nil`.
    Default is `no-[assign-name]`

  ### Options for `:string`, `:atom` and `:integer` defining `values` or `values!`

  * `:prefix` - the prefix of the variant name generated for each value listed in `values` or `values!`.
    Default is `[assign-name]-`.

  ### Options for other types

  * `:not_nil` - the name of the variant when the value is not `nil`.
    Default is the assign name.
  * `:nil` - the name of the variant when the value is `nil`.
    Default is `no-[assign-name]`.

  """

  use Mix.Task
  @recursive true

  alias Mix.Task.Compiler.Diagnostic

  @switches [
    return_errors: :boolean,
    warnings_as_errors: :boolean
  ]

  @assets_opts [
    :hooks_output_dir,
    :css_output_file,
    :enable_variants,
    :variants_output_file
  ]

  @doc false
  def run(args) do
    # Do nothing if it's a dependency. We only have to run it once for the main project
    if "--from-mix-deps-compile" in args do
      {:noop, []}
    else
      {compile_opts, _argv, _err} = OptionParser.parse(args, switches: @switches)
      opts = Application.get_env(:surface, :compiler, [])
      asset_opts = Keyword.take(opts, @assets_opts)
      asset_components = Surface.components()
      project_components = Surface.components(only_current_project: true)

      [
        Mix.Tasks.Compile.Surface.ValidateComponents.validate(project_components),
        Mix.Tasks.Compile.Surface.AssetGenerator.run(asset_components, asset_opts)
      ]
      |> List.flatten()
      |> handle_diagnostics(compile_opts)
    end
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
