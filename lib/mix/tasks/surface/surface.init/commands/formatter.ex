defmodule Mix.Tasks.Surface.Init.Commands.Formatter do
  alias Mix.Tasks.Surface.Init.Patchers

  @behaviour Mix.Tasks.Surface.Init.Command

  @impl true
  def file_patchers(%{formatter: true}) do
    if Version.match?(System.version(), ">= 1.13.0") do
      %{
        ".formatter.exs" => [
          add_sface_files_to_inputs_in_formatter_config(),
          add_surface_to_import_deps_in_formatter_config(),
          add_formatter_plugin_to_formatter_config()
        ]
      }
    else
      %{
        "mix.exs" => [
          add_surface_formatter_to_mix_deps()
        ],
        ".formatter.exs" => [
          add_surface_inputs_to_formatter_config(),
          add_surface_to_import_deps_in_formatter_config()
        ]
      }
    end
  end

  def file_patchers(_assigns), do: []

  @impl true
  def create_files(_assigns), do: []

  def add_surface_formatter_to_mix_deps() do
    %{
      name: "Add `surface_formatter` dependency",
      update_deps: [:surface_formatter],
      patch: &Patchers.MixExs.add_dep(&1, ":surface_formatter", ~S("~> 0.6.0")),
      instructions: """
      Add `surface_formatter` to the list of dependencies in `mix.exs`.

      # Example

      ```
      def deps do
        [
          {:surface_formatter, "~> 0.6.0"}
        ]
      end
      ```
      """
    }
  end

  def add_surface_inputs_to_formatter_config() do
    %{
      name: "Add file extensions to :surface_inputs",
      patch: &Patchers.Formatter.add_config(&1, :surface_inputs, ~S(["{lib,test}/**/*.{ex,exs,sface}"])),
      instructions: """
      In case you'll be using `mix format`, make sure you add the required file patterns
      to your `.formatter.exs` file.

      # Example

      ```
      [
        surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"],
        ...
      ]
      ```
      """
    }
  end

  def add_sface_files_to_inputs_in_formatter_config() do
    %{
      name: "Add sface files to :inputs",
      patch: &Patchers.Formatter.add_input(&1, ~S("{lib,test}/**/*.sface")),
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
      patch: &Patchers.Formatter.add_import_dep(&1, ":surface"),
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
      patch: &Patchers.Formatter.add_plugin(&1, "Surface.Formatter.Plugin"),
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
