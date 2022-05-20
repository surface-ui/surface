defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Formatter do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def specs(%{formatter: true}) do
    if Version.match?(System.version(), ">= 1.13.0") do
      [
        {:patch, ".formatter.exs",
         [
           add_sface_files_to_inputs_in_formatter_config(),
           add_surface_to_import_deps_in_formatter_config(),
           add_formatter_plugin_to_formatter_config()
         ]}
      ]
    else
      [
        {:patch, "mix.exs",
         [
           add_surface_formatter_to_mix_deps()
         ]},
        {:patch, ".formatter.exs",
         [
           add_surface_inputs_to_formatter_config(),
           add_surface_to_import_deps_in_formatter_config()
         ]}
      ]
    end
  end

  def specs(_assigns), do: []

  def add_surface_formatter_to_mix_deps() do
    %{
      name: "Add `surface_formatter` dependency",
      update_deps: [:surface_formatter],
      patch: &FilePatchers.MixExs.add_dep(&1, ":surface_formatter", ~S("~> 0.7.4")),
      instructions: """
      Add `surface_formatter` to the list of dependencies in `mix.exs`.

      # Example

      ```
      def deps do
        [
          {:surface_formatter, "~> 0.7.4"}
        ]
      end
      ```
      """
    }
  end

  def add_surface_inputs_to_formatter_config() do
    %{
      name: "Add file extensions to :surface_inputs",
      patch:
        &FilePatchers.Formatter.add_config(
          &1,
          :surface_inputs,
          ~S(["{lib,test,priv/catalogue}/**/*.{ex,exs,sface}"])
        ),
      instructions: """
      In case you'll be using `mix format`, make sure you add the required file patterns
      to your `.formatter.exs` file.

      # Example

      ```
      [
        surface_inputs: ["{lib,test,priv/catalogue}/**/*.{ex,exs,sface}"],
        ...
      ]
      ```
      """
    }
  end

  def add_sface_files_to_inputs_in_formatter_config() do
    %{
      name: "Add sface files to :inputs",
      patch: &FilePatchers.Formatter.add_input(&1, ~S("{lib,test}/**/*.sface")),
      instructions: """
      In case you'll be using `mix format`, make sure you add the required file patterns
      to your `.formatter.exs` file.

      # Example

      ```
      [
        inputs: ["{lib,test}/**/*.sface", ...],
        ...
      ]
      ```
      """
    }
  end

  def add_surface_to_import_deps_in_formatter_config() do
    %{
      name: "Add :surface to :import_deps",
      patch: &FilePatchers.Formatter.add_import_dep(&1, ":surface"),
      instructions: """
      In case you'll be using `mix format`, make sure you add `:surface` to the `import_deps`
      configuration in your `.formatter.exs` file.

      # Example

      ```
      [
        import_deps: [:ecto, :phoenix, :surface],
        ...
      ]
      ```
      """
    }
  end

  def add_formatter_plugin_to_formatter_config() do
    %{
      name: "Add Surface.Formatter.Plugin to :plugins",
      patch: &FilePatchers.Formatter.add_plugin(&1, "Surface.Formatter.Plugin"),
      instructions: """
      In case you'll be using `mix format`, make sure you add `Surface.Formatter.Plugin`
      to the `plugins` in your `.formatter.exs` file.

      # Example

      ```
      [
        plugins: [Surface.Formatter.Plugin],
        ...
      ]
      ```
      """
    }
  end
end
