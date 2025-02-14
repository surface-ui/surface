defmodule Surface.MixProject do
  use Mix.Project

  @version "0.12.1"
  @source_url "https://github.com/surface-ui/surface"
  @homepage_url "https://surface-ui.org"

  def project do
    [
      app: :surface,
      version: @version,
      elixir: "~> 1.13",
      description: "A component based library for Phoenix LiveView",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      preferred_cli_env: [docs: :docs],
      # Docs
      name: "Surface",
      source_url: @source_url,
      homepage_url: @homepage_url,
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      env: [csrf_token_reader: {Plug.CSRFProtection, :get_csrf_token_for, []}]
    ]
  end

  defp elixirc_paths(:dev), do: ["lib"] ++ catalogues()
  defp elixirc_paths(:test), do: ["lib", "test/support"] ++ catalogues()
  defp elixirc_paths(_), do: ["lib"]

  defp catalogues do
    ["priv/catalogue"]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix_live_view, "~> 0.19.0 or ~> 0.20.10 or ~> 1.0"},
      {:sourceror, "~> 1.0"},
      {:blend, "~> 0.3.0", only: :dev},
      {:jason, "~> 1.0", only: :test},
      {:floki, "~> 0.35", only: :test},
      {:ex_doc, ">= 0.31.0", only: :docs}
    ]
  end

  defp docs do
    [
      main: "Surface",
      logo: "assets/surface-logo.png",
      source_ref: "v#{@version}",
      groups_for_modules: [
        Components: ~r/Surface.Components/,
        Catalogue: ~r/Catalogue/,
        Compiler: ~r/Compiler/,
        Directives: ~r/Surface.Directive/,
        AST: ~r/AST/,
        Formatter: [~r/Formatter$/, ~r/Formatter.Phase/]
      ],
      nest_modules_by_prefix: [
        Surface.AST,
        Surface.Catalogue,
        Surface.Compiler,
        Surface.Components,
        Surface.Directive,
        Surface.Formatter.Phases
      ],
      extras: [
        "CHANGELOG.md",
        "MIGRATING.md",
        "LICENSE.md"
      ]
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{
        Website: @homepage_url,
        Changelog: "https://hexdocs.pm/surface/changelog.html",
        GitHub: @source_url
      },
      files: ~w(
        README.md
        CHANGELOG.md
        LICENSE.md
        mix.exs
        .formatter.exs
        lib
        priv/templates/surface.init
      )
    }
  end
end
