defmodule Surface.MixProject do
  use Mix.Project

  @version "0.1.0-alpha.0"

  def project do
    [
      app: :surface,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:nimble_parsec, "~> 0.5.0"},
      {:jason, "~> 1.0"},
      {:phoenix_live_view, "~> 0.8.0"},
      {:floki, "~> 0.25.0", only: :test},
      {:ex_doc, ">= 0.19.0", only: :docs}
    ]
  end

  defp docs do
    [
      main: "Surface",
      source_ref: "v#{@version}",
      source_url: "https://github.com/msaraiva/surface"
    ]
  end
end
