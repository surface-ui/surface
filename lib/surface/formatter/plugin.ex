defmodule Surface.Formatter.Plugin do
  @moduledoc """
  An [Elixir formatter
  plugin](https://hexdocs.pm/mix/1.13.0-rc.1/Mix.Tasks.Format.html#module-plugins)
  for Surface code.

  Elixir 1.13 introduced formatter plugins, allowing the Surface formatter to
  run during `mix format` instead of requiring developers to run `mix
  surface.format` separately.

  To format Surface code using Elixir 1.12 or earlier, use `mix
  surface.format`.

  ### `.formatter.exs` setup

  Add to `:plugins` in `.formatter.exs` in order to format `~F` sigils and
  `.sface` files when running `mix format`.

  Only works on files matching patterns in `:inputs`, so add patterns for
  all Surface files to ensure they're formatted.

      # in .formatter.exs
      [
        ...,
        import_deps: [:surface],
        plugins: [Surface.Formatter.Plugin],

        # add patterns matching all .sface files and all .ex files with ~F sigils
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs,sface}"],

        # THE FOLLOWING ARE OPTIONAL:

        # set desired line length for both Elixir's code formatter and this one
        # (only affects opening tags in Surface)
        line_length: 80,

        # or, set line length only for Surface code (overrides `line_length`)
        surface_line_length: 84
      ]

  ### Options

  In `.formatter.exs`, the following options can be provided:

  - `:line_length` - Maximum line length of an opening tag before
    SurfaceFormatter attempts to wrap it onto multiple lines. This option is
    used by `Code.format_string!/2` and `mix format` and defaults to 98.
  - `:surface_line_length` - Overrides `:line_length`; useful for setting
    separate desired line length for Surface code and non-Surface Elixir code.

  """

  if Version.match?(System.version(), ">= 1.13.0") do
    @behaviour Mix.Tasks.Format
  end

  def features(_opts) do
    [sigils: [:F], extensions: [".sface"]]
  end

  def format(contents, opts) do
    line_length = opts[:surface_line_length] || opts[:line_length]
    opts = if line_length, do: Keyword.put(opts, :line_length, line_length), else: opts
    Surface.Formatter.format_string!(contents, opts)
  end
end
