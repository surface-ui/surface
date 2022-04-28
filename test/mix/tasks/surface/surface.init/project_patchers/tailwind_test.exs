defmodule Mix.Tasks.Surface.Init.ProjectPatchers.TailwindTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Tailwind

  describe "add_tailwind_to_mix_deps" do
    test "add :tailwind to deps" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

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

      {:patched, updated_code} = Patcher.patch_code(code, add_tailwind_to_mix_deps())

      assert updated_code == """
             defmodule MyApp.MixProject do
               use Mix.Project

               # Specifies your project dependencies.
               defp deps do
                 [
                   {:phoenix, "~> 1.6.0"},
                   {:surface, "~> 0.5.2"},
                   {:plug_cowboy, "~> 2.5"},
                   {:tailwind, "~> 0.1", runtime: Mix.env() == :dev}
                 ]
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        # Specifies your project dependencies.
        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"},
            {:plug_cowboy, "~> 2.5"},
            {:tailwind, "~> 0.1", runtime: Mix.env() == :dev}
          ]
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_tailwind_to_mix_deps())
    end
  end

  describe "update_alias_assets_deploy_to_run_tailwind" do
    test "Update alias `assets.deploy` to run `tailwind default --minify`" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        # See the documentation for `Mix` for more info on aliases.
        defp aliases do
          [
            setup: ["deps.get"],
            "assets.deploy": ["esbuild default --minify", "phx.digest"],
            "ecto.setup": ["ecto.create --quiet", "ecto.migrate  --quiet"]
          ]
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, update_alias_assets_deploy_to_run_tailwind())

      assert updated_code == """
             defmodule MyApp.MixProject do
               use Mix.Project

               # See the documentation for `Mix` for more info on aliases.
               defp aliases do
                 [
                   setup: ["deps.get"],
                   "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
                   "ecto.setup": ["ecto.create --quiet", "ecto.migrate  --quiet"]
                 ]
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        # See the documentation for `Mix` for more info on aliases.
        defp aliases do
          [
            setup: ["deps.get"],
            "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
            "ecto.setup": ["ecto.create --quiet", "ecto.migrate  --quiet"]
          ]
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, update_alias_assets_deploy_to_run_tailwind())
    end

    test "don't apply it if maybe already patched" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        # See the documentation for `Mix` for more info on aliases.
        defp aliases do
          [
            setup: ["deps.get"],
            "assets.deploy": ["tailwind other --minify", "esbuild default --minify", "phx.digest"],
            "ecto.setup": ["ecto.create --quiet", "ecto.migrate  --quiet"]
          ]
        end
      end
      """

      assert {:maybe_already_patched, ^code} =
               Patcher.patch_code(code, update_alias_assets_deploy_to_run_tailwind())
    end
  end

  describe "configure_tailwind" do
    test "add tailwind config if no existing config is found" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      {:patched, updated_code} = Patcher.patch_code(code, configure_tailwind())

      assert updated_code == ~S"""
             import Config

             config :tailwind,
               version: "3.0.23",
               default: [
                 args: ~w(
                   --config=tailwind.config.js
                   --input=css/app.css
                   --output=../priv/static/assets/app.css
                 ),
                 cd: Path.expand("../assets", __DIR__)
               ]

             # Use Jason for JSON parsing in Phoenix
             config :phoenix, :json_library, Jason

             # Import environment specific config. This must remain at the bottom
             # of this file so it overrides the configuration defined above.
             import_config "#{config_env()}.exs"
             """
    end

    test "don't apply it if already patched" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      config :tailwind,
        version: "3.0.23",
        default: [
          args: ~w(
            --config=tailwind.config.js
            --input=css/app.css
            --output=../priv/static/assets/app.css
          ),
          cd: Path.expand("../assets", __DIR__)
        ]

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, configure_tailwind())
    end
  end

  describe "add_tailwind_watcher_to_endpoint_config" do
    test "add a tailwind watcher to the endpoint config" do
      code = """
      import Config

      # Some comments
      config :my_app, MyAppWeb.Endpoint,
        debug_errors: true,
        watchers: [
          # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
          esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
          esbuild: {Esbuild, :install_and_run, [:catalogue, ~w(--sourcemap=inline --watch)]}
        ]

      # Initialize plugs at runtime for faster development compilation
      config :phoenix, :plug_init_mode, :runtime
      """

      {:patched, updated_code} =
        Patcher.patch_code(code, add_tailwind_watcher_to_endpoint_config(:my_app, MyAppWeb))

      assert updated_code == """
             import Config

             # Some comments
             config :my_app, MyAppWeb.Endpoint,
               debug_errors: true,
               watchers: [
                 # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
                 esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
                 esbuild: {Esbuild, :install_and_run, [:catalogue, ~w(--sourcemap=inline --watch)]},
                 tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
               ]

             # Initialize plugs at runtime for faster development compilation
             config :phoenix, :plug_init_mode, :runtime
             """
    end

    test "don't apply it if already patched" do
      code = """
      import Config

      # Some comments
      config :my_app, MyAppWeb.Endpoint,
        debug_errors: true,
        watchers: [
          # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
          esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
          tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
        ]

      # Initialize plugs at runtime for faster development compilation
      config :phoenix, :plug_init_mode, :runtime
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(
                 code,
                 add_tailwind_watcher_to_endpoint_config(:my_app, MyAppWeb)
               )
    end
  end

  describe "remove_import_app_css" do
    test "Remove import with comments" do
      code = """
      // We import the CSS which is extracted to its own file by esbuild.
      // Remove this line if you add a your own CSS build pipeline (e.g postcss).
      import "../css/app.css"

      import {LiveSocket} from "phoenix_live_view"
      """

      {:patched, updated_code} = Patcher.patch_code(code, remove_import_app_css())

      assert updated_code == """
             import {LiveSocket} from "phoenix_live_view"
             """
    end

    test "don't apply it if already patched" do
      code = """
      import {LiveSocket} from "phoenix_live_view"
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, remove_import_app_css())
    end
  end

  describe "add_tailwind_directives" do
    test "Add tailwind directives" do
      code = """
      /* This file is for your main application CSS */
      @import "./phoenix.css";
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_tailwind_directives())

      assert updated_code == """
             @tailwind base;
             @tailwind components;
             @tailwind utilities;

             /* This file is for your main application CSS */
             @import "./phoenix.css";
             """
    end

    test "don't apply it if already patched" do
      code = """
      @tailwind base;

      /* This file is for your main application CSS */
      @import "./phoenix.css";
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_tailwind_directives())
    end
  end
end
