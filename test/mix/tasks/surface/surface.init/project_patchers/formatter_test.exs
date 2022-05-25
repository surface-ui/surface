defmodule Mix.Tasks.Surface.Init.ProjectPatchers.FormatterTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Formatter

  describe "add_surface_formatter_to_mix_deps" do
    test "add :surface_formatter to deps" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app
          ]
        end

        # Specifies your project dependencies.
        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"},
            {:plug_cowboy, "~> 2.5"}
          ]
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_formatter_to_mix_deps())

      assert updated_code == """
             defmodule MyApp.MixProject do
               use Mix.Project

               def project do
                 [
                   app: :my_app
                 ]
               end

               # Specifies your project dependencies.
               defp deps do
                 [
                   {:phoenix, "~> 1.6.0"},
                   {:surface, "~> 0.5.2"},
                   {:plug_cowboy, "~> 2.5"},
                   {:surface_formatter, "~> 0.7.4"}
                 ]
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app
          ]
        end

        # Specifies which paths to compile per environment.
        defp elixirc_paths(:test), do: ["lib", "test/support"]
        defp elixirc_paths(:dev), do: ["lib"]
        defp elixirc_paths(_), do: ["lib"]

        # Specifies your project dependencies.
        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"},
            {:surface_formatter, "~> 0.7.4"},
            {:plug_cowboy, "~> 2.5"}
          ]
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_surface_formatter_to_mix_deps())
    end
  end

  describe "add_surface_inputs_to_formatter_config" do
    test "add :surface_inputs" do
      code = """
      [
        import_deps: [:phoenix, :ecto],
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
      ]
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_inputs_to_formatter_config())

      assert updated_code == """
             [
               import_deps: [:phoenix, :ecto],
               inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
               surface_inputs: ["{lib,test,priv/catalogue}/**/*.{ex,exs,sface}"]
             ]
             """
    end

    test "don't apply it if already patched" do
      code = """
      [
        import_deps: [:phoenix, :ecto],
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
        surface_inputs: ["{lib,test,priv}/**/*.{ex,exs,sface}"]
      ]
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_surface_inputs_to_formatter_config())
    end
  end

  describe "add_surface_to_import_deps_in_formatter_config" do
    test "add :surface to :import_deps" do
      code = """
      [
        import_deps: [:phoenix, :ecto],
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
      ]
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_to_import_deps_in_formatter_config())

      assert updated_code == """
             [
               import_deps: [:phoenix, :ecto, :surface],
               inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
             ]
             """
    end

    test "don't apply it if already patched" do
      code = """
      [
        import_deps: [:phoenix, :ecto, :surface],
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
      ]
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_surface_to_import_deps_in_formatter_config())
    end
  end

  describe "add_formatter_plugin_to_formatter_config" do
    test "add `plugins: [Surface.Formatter.Plugin]` if :plugins don't exist" do
      code = """
      [
        import_deps: [:phoenix, :ecto, :surface]
      ]
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_formatter_plugin_to_formatter_config())

      assert updated_code == """
             [
               import_deps: [:phoenix, :ecto, :surface],
               plugins: [Surface.Formatter.Plugin]
             ]
             """
    end

    test "add Surface.Formatter.Plugin to :plugins if :plugins already exists" do
      code = """
      [
        import_deps: [:phoenix, :ecto, :surface],
        plugins: [WhateverPlugin]
      ]
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_formatter_plugin_to_formatter_config())

      assert updated_code == """
             [
               import_deps: [:phoenix, :ecto, :surface],
               plugins: [WhateverPlugin, Surface.Formatter.Plugin]
             ]
             """
    end

    test "don't apply it if already patched" do
      code = """
      [
        import_deps: [:phoenix, :ecto, :surface],
        plugins: [Surface.Formatter.Plugin]
      ]
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_formatter_plugin_to_formatter_config())

      code = """
      [
        import_deps: [:phoenix, :ecto, :surface],
        plugins: [WhateverPlugin, Surface.Formatter.Plugin]
      ]
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_formatter_plugin_to_formatter_config())
    end
  end
end
