defmodule Mix.Tasks.Surface.Init.ProjectPatchers.CatalogueTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Catalogue

  describe "add_surface_catalogue_to_mix_deps" do
    test "add :surface_catalogue to deps" do
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

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_catalogue_to_mix_deps())

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
                   {:surface_catalogue, #{catalogue_requirement()}}
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
            {:surface_catalogue, "~> 0.2.0"},
            {:plug_cowboy, "~> 2.5"}
          ]
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_surface_catalogue_to_mix_deps())
    end
  end

  describe "configure_catalogue_in_mix_exs" do
    test "add :surface_catalogue to deps" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        # Specifies which paths to compile per environment.
        defp elixirc_paths(:test), do: ["lib", "test/support"]
        defp elixirc_paths(_), do: ["lib"]

        # Specifies your project dependencies.
        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"},
            {:plug_cowboy, "~> 2.5"},
            {:surface_catalogue, "~> 0.2.0"}
          ]
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, configure_catalogue_in_mix_exs())

      assert updated_code == """
             defmodule MyApp.MixProject do
               use Mix.Project

               # Specifies which paths to compile per environment.
               defp elixirc_paths(:test), do: ["lib", "test/support"] ++ catalogues()
               defp elixirc_paths(:dev), do: ["lib"] ++ catalogues()
               defp elixirc_paths(_), do: ["lib"]

               # Specifies your project dependencies.
               defp deps do
                 [
                   {:phoenix, "~> 1.6.0"},
                   {:surface, "~> 0.5.2"},
                   {:plug_cowboy, "~> 2.5"},
                   {:surface_catalogue, "~> 0.2.0"}
                 ]
               end

               def catalogues do
                 [
                   "priv/catalogue"
                 ]
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        # Specifies which paths to compile per environment.
        defp elixirc_paths(:test), do: ["lib", "test/support"]
        defp elixirc_paths(:dev), do: ["lib"] ++ catalogues()
        defp elixirc_paths(_), do: ["lib"]

        # Specifies your project dependencies.
        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"},
            {:plug_cowboy, "~> 2.5"},
            {:surface_catalogue, "~> 0.2.0"}
          ]
        end

        def catalogues do
          [
            "priv/catalogue"
          ]
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, configure_catalogue_in_mix_exs())
    end

    test "don't apply it if maybe already patched" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        # Specifies which paths to compile per environment.
        defp elixirc_paths(:test), do: ["lib", "test/support"]
        defp elixirc_paths(:dev), do: ["lib"]
        defp elixirc_paths(_), do: ["lib"]

        # Specifies your project dependencies.
        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"},
            {:surface_catalogue, "~> 0.2.0"},
            {:plug_cowboy, "~> 2.5"}
          ]
        end
      end
      """

      assert {:maybe_already_patched, ^code} = Patcher.patch_code(code, configure_catalogue_in_mix_exs())
    end
  end

  describe "configure_catalogue_esbuild" do
    test "add whole esbuild config with catalogue entry if no esbuild config is found" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      {:patched, updated_code} = Patcher.patch_code(code, configure_catalogue_esbuild())

      assert updated_code == ~S"""
             import Config

             config :esbuild,
               catalogue: [
                 args: ~w(../deps/surface_catalogue/assets/js/app.js --bundle --target=es2016 --minify --outdir=../priv/static/assets/catalogue),
                 cd: Path.expand("../assets", __DIR__),
                 env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
               ]

             # Use Jason for JSON parsing in Phoenix
             config :phoenix, :json_library, Jason

             # Import environment specific config. This must remain at the bottom
             # of this file so it overrides the configuration defined above.
             import_config "#{config_env()}.exs"
             """
    end

    test "add catalogue entry if esbuild config has already been set" do
      profile = Enum.random(["default", "surface_init_test"])

      code = ~s"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      # Configure esbuild (the version is required)
      config :esbuild,
        version: "0.14.10",
        #{profile}: [
          args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
          cd: Path.expand("../assets", __DIR__),
          env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
        ]

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "\#{config_env()}.exs"
      """

      {:patched, updated_code} = Patcher.patch_code(code, configure_catalogue_esbuild())

      assert updated_code == ~s"""
             import Config

             # Use Jason for JSON parsing in Phoenix
             config :phoenix, :json_library, Jason

             # Configure esbuild (the version is required)
             config :esbuild,
               version: "0.14.10",
               #{profile}: [
                 args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
                 cd: Path.expand("../assets", __DIR__),
                 env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
               ],
               catalogue: [
                 args: ~w(../deps/surface_catalogue/assets/js/app.js --bundle --target=es2016 --minify --outdir=../priv/static/assets/catalogue),
                 cd: Path.expand("../assets", __DIR__),
                 env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
               ]

             # Import environment specific config. This must remain at the bottom
             # of this file so it overrides the configuration defined above.
             import_config "\#{config_env()}.exs"
             """
    end

    test "don't apply it if already patched" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      # Configure esbuild (the version is required)
      config :esbuild,
        version: "0.14.10",
        default: [
          cd: Path.expand("../assets", __DIR__),
        ],
        catalogue: [
          cd: Path.expand("../assets", __DIR__),
        ]

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, configure_catalogue_esbuild())
    end
  end

  describe "add_catalogue_live_reload_pattern_to_endpoint_config" do
    test "update live_reload patterns" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir, :surface],
        live_reload: [
          patterns: [
            ~r"lib/my_app_web/(live|views|components)/.*(ex|sface|js)$",
            ~r"lib/my_app_web/templates/.*(eex)$"
          ]
        ]
      """

      {:patched, updated_code} =
        Patcher.patch_code(code, add_catalogue_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb))

      assert updated_code == """
             import Config

             # Watch static and templates for browser reloading.
             config :my_app, MyAppWeb.Endpoint,
               reloadable_compilers: [:phoenix, :elixir, :surface],
               live_reload: [
                 patterns: [
                   ~r"lib/my_app_web/(live|views|components)/.*(ex|sface|js)$",
                   ~r"lib/my_app_web/templates/.*(eex)$",
                   ~r"priv/catalogue/.*(ex)$"
                 ]
               ]
             """
    end

    test "don't apply it if already patched" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir, :surface],
        live_reload: [
          patterns: [
            ~r"lib/my_app_web/(live|views|components)/.*(ex|sface|js)$",
            ~r"lib/my_app_web/templates/.*(eex)$",
            ~r"priv/catalogue/.*(ex)$"
          ]
        ]
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(
                 code,
                 add_catalogue_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb)
               )
    end
  end

  describe "add_catalogue_esbuild_watcher_to_endpoint_config" do
    test "update live_reload patterns" do
      code = """
      import Config

      # Some comments
      config :my_app, MyAppWeb.Endpoint,
        debug_errors: true,
        watchers: [
          # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
          esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
        ]

      # Initialize plugs at runtime for faster development compilation
      config :phoenix, :plug_init_mode, :runtime
      """

      {:patched, updated_code} =
        Patcher.patch_code(code, add_catalogue_esbuild_watcher_to_endpoint_config(:my_app, MyAppWeb))

      assert updated_code == """
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
          esbuild: {Esbuild, :install_and_run, [:catalogue, ~w(--sourcemap=inline --watch)]}
        ]

      # Initialize plugs at runtime for faster development compilation
      config :phoenix, :plug_init_mode, :runtime
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(
                 code,
                 add_catalogue_esbuild_watcher_to_endpoint_config(:my_app, MyAppWeb)
               )
    end
  end

  describe "configure_catalogue_route" do
    test "add import Surface.Catalogue.Router and the catalogue route" do
      code = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, configure_catalogue_route(MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb.Router do
               use MyAppWeb, :router

               import Surface.Catalogue.Router

               pipeline :browser do
                 plug :accepts, ["html"]
                 plug :fetch_session
               end

               if Mix.env() == :dev do
                 scope "/" do
                   pipe_through :browser
                   surface_catalogue "/catalogue"
                 end
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb.Router do
        use MyDemoWeb, :router

        import Surface.Catalogue.Router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, configure_catalogue_route(MyAppWeb))
    end
  end
end
