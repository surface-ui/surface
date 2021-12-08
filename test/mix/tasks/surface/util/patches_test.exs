defmodule Mix.Tasks.Surface.Init.PatchesTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patches
  alias Mix.Tasks.Surface.Init.Patcher

  describe "add_surface_to_mix_compilers" do
    test "add :surface to compilers" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            compilers: [:gettext] ++ Mix.compilers(),
            start_permanent: Mix.env() == :prod
          ]
        end

        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"}
          ]
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_surface_to_mix_compilers())

      assert updated_code == """
             defmodule MyApp.MixProject do
               use Mix.Project

               def project do
                 [
                   app: :my_app,
                   compilers: [:gettext] ++ Mix.compilers() ++ [:surface],
                   start_permanent: Mix.env() == :prod
                 ]
               end

               defp deps do
                 [
                   {:phoenix, "~> 1.6.0"},
                   {:surface, "~> 0.5.2"}
                 ]
               end
             end
             """
    end

    test "add :surface to compilers when there are no other compilers" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            compilers: Mix.compilers(),
            start_permanent: Mix.env() == :prod
          ]
        end

        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"}
          ]
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_surface_to_mix_compilers())

      assert updated_code == """
             defmodule MyApp.MixProject do
               use Mix.Project

               def project do
                 [
                   app: :my_app,
                   compilers: Mix.compilers() ++ [:surface],
                   start_permanent: Mix.env() == :prod
                 ]
               end

               defp deps do
                 [
                   {:phoenix, "~> 1.6.0"},
                   {:surface, "~> 0.5.2"}
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
            app: :my_app,
            compilers: [:gettext] ++ Mix.compilers() ++ [:surface],
            start_permanent: Mix.env() == :prod
          ]
        end

        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"}
          ]
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.add_surface_to_mix_compilers())
    end

    test "don't apply it if maybe already patched" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
            compilers: [:whatever, :surface],
            start_permanent: Mix.env() == :prod
          ]
        end

        defp deps do
          [
            {:phoenix, "~> 1.6.0"},
            {:surface, "~> 0.5.2"}
          ]
        end
      end
      """

      assert {:maybe_already_patched, ^code} = Patcher.patch_code(code, Patches.add_surface_to_mix_compilers())
    end
  end

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

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_surface_catalogue_to_mix_deps())

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
                   {:surface_catalogue, "~> 0.2.0"}
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

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.add_surface_catalogue_to_mix_deps())
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

      {:patched, updated_code} = Patcher.patch_code(code, Patches.configure_catalogue_in_mix_exs())

      assert updated_code == """
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

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.configure_catalogue_in_mix_exs())
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

      assert {:maybe_already_patched, ^code} = Patcher.patch_code(code, Patches.configure_catalogue_in_mix_exs())
    end
  end

  describe "add_import_to_view_macro" do
    test "add import Surface" do
      code = """
      defmodule MyAppWeb do
        def view do
          quote do
            use Phoenix.View,
              root: "lib/my_app_web/templates",
              namespace: MyAppWeb

            # Include shared imports and aliases for views
            unquote(view_helpers())
          end
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_import_surface_to_view_macro(MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb do
               def view do
                 quote do
                   use Phoenix.View,
                     root: "lib/my_app_web/templates",
                     namespace: MyAppWeb

                   # Include shared imports and aliases for views
                   unquote(view_helpers())
                   import Surface
                 end
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb do
        def view do
          quote do
            use Phoenix.View,
              root: "lib/my_app_web/templates",
              namespace: MyAppWeb

            # Include shared imports and aliases for views
            unquote(view_helpers())
            import Surface
          end
        end
      end
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(code, Patches.add_import_surface_to_view_macro(MyAppWeb))
    end
  end

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

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_surface_formatter_to_mix_deps())

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
                   {:surface_formatter, "~> 0.6.0"}
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
            {:surface_formatter, "~> 0.6.0"},
            {:plug_cowboy, "~> 2.5"}
          ]
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.add_surface_formatter_to_mix_deps())
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

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_surface_inputs_to_formatter_config())

      assert updated_code == """
             [
               import_deps: [:phoenix, :ecto],
               inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
               surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"]
             ]
             """
    end

    test "don't apply it if already patched" do
      code = """
      [
        import_deps: [:phoenix, :ecto],
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
        surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"]
      ]
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.add_surface_inputs_to_formatter_config())
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

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_surface_to_import_deps_in_formatter_config())

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

      assert {:already_patched, ^code} =
               Patcher.patch_code(code, Patches.add_surface_to_import_deps_in_formatter_config())
    end
  end

  describe "add_formatter_plugin_to_formatter_config" do
    test "add `plugins: [Surface.Formatter.Plugin]` if :plugins don't exist" do
      code = """
      [
        import_deps: [:phoenix, :ecto, :surface]
      ]
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_formatter_plugin_to_formatter_config())

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

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_formatter_plugin_to_formatter_config())

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

      assert {:already_patched, ^code} =
               Patcher.patch_code(code, Patches.add_formatter_plugin_to_formatter_config())

      code = """
      [
        import_deps: [:phoenix, :ecto, :surface],
        plugins: [WhateverPlugin, Surface.Formatter.Plugin]
      ]
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(code, Patches.add_formatter_plugin_to_formatter_config())
    end
  end

  describe "add_surface_to_reloadable_compilers_in_endpoint_config" do
    defmodule Elixir.MyTestAppWeb.Endpoint do
      def config(:reloadable_compilers) do
        [:gettext, :elixir]
      end
    end

    test "add reloadable_compilers if there's no :reloadable_compilers key" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyTestAppWeb.Endpoint,
        live_reload: [
          patterns: []
        ]
      """

      {:patched, updated_code} =
        Patcher.patch_code(
          code,
          Patches.add_surface_to_reloadable_compilers_in_endpoint_config(:my_app, MyTestAppWeb)
        )

      assert updated_code == """
             import Config

             # Watch static and templates for browser reloading.
             config :my_app, MyTestAppWeb.Endpoint,
               reloadable_compilers: [:gettext, :elixir, :surface],
               live_reload: [
                 patterns: []
               ]
             """
    end

    test "add :surface to reloadable_compilers if :reloadable_compilers already exists" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyTestAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir],
        live_reload: [
          patterns: []
        ]
      """

      {:patched, updated_code} =
        Patcher.patch_code(
          code,
          Patches.add_surface_to_reloadable_compilers_in_endpoint_config(:my_app, MyTestAppWeb)
        )

      assert updated_code == """
             import Config

             # Watch static and templates for browser reloading.
             config :my_app, MyTestAppWeb.Endpoint,
               reloadable_compilers: [:phoenix, :elixir, :surface],
               live_reload: [
                 patterns: []
               ]
             """
    end

    test "don't apply it if already patched" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyTestAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir, :surface],
        live_reload: [
          patterns: []
        ]
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(
                 code,
                 Patches.add_surface_to_reloadable_compilers_in_endpoint_config(:my_app, MyTestAppWeb)
               )
    end
  end

  describe "add_surface_live_reload_pattern_to_endpoint_config" do
    test "update live_reload patterns" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir, :surface],
        live_reload: [
          patterns: [
            ~r"lib/my_app_web/(live|views)/.*(ex)$",
            ~r"lib/my_app_web/templates/.*(eex)$"
          ]
        ]
      """

      {:patched, updated_code} =
        Patcher.patch_code(
          code,
          Patches.add_surface_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb, "lib/my_app_web")
        )

      assert updated_code == """
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
            ~r"lib/my_app_web/templates/.*(eex)$"
          ]
        ]
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(
                 code,
                 Patches.add_surface_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb, "lib/my_app_web")
               )
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
        Patcher.patch_code(code, Patches.add_catalogue_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb))

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
                 Patches.add_catalogue_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb)
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

      {:patched, updated_code} = Patcher.patch_code(code, Patches.configure_catalogue_route(MyAppWeb))

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

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.configure_catalogue_route(MyAppWeb))
    end
  end

  describe "configure_demo_route" do
    test "add the demo route" do
      code = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        scope "/", MyAppWeb do
          pipe_through :browser

          get "/", PageController, :index
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.configure_demo_route(MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb.Router do
               use MyAppWeb, :router

               scope "/", MyAppWeb do
                 pipe_through :browser

                 get "/", PageController, :index
                 live "/demo", Demo
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        scope "/", MyAppWeb do
          pipe_through :browser

          get "/", PageController, :index
          live "/demo", Demo
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.configure_demo_route(MyAppWeb))
    end
  end

  describe "patch_js_hooks" do
    test "configure JS hooks" do
      code = """
      // We import the CSS which is extracted to its own file by esbuild.
      import "../css/app.css"

      import {LiveSocket} from "phoenix_live_view"
      import topbar from "../vendor/topbar"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

      // connect if there are any LiveViews on the page
      liveSocket.connect()

      window.liveSocket = liveSocket
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.js_hooks())

      assert updated_code == """
             // We import the CSS which is extracted to its own file by esbuild.
             import "../css/app.css"

             import {LiveSocket} from "phoenix_live_view"
             import topbar from "../vendor/topbar"
             import Hooks from "./_hooks"

             let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
             let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

             // connect if there are any LiveViews on the page
             liveSocket.connect()

             window.liveSocket = liveSocket
             """
    end

    test "don't apply it if already patched" do
      code = """
      // We import the CSS which is extracted to its own file by esbuild.
      import "../css/app.css"

      import {LiveSocket} from "phoenix_live_view"
      import topbar from "../vendor/topbar"
      import Hooks from "./_hooks"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

      // connect if there are any LiveViews on the page
      liveSocket.connect()

      window.liveSocket = liveSocket
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.js_hooks())
    end

    test "don't apply it if code has been modified" do
      code = """
      // We import the CSS which is extracted to its own file by esbuild.
      import "../css/app.css"

      import {LiveSocket} from "phoenix_live_view"
      import topbar from "../vendor/topbar"
      import Hooks from "./_hooks"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

      // This line has been modified
      let liveSocket =
        new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

      // connect if there are any LiveViews on the page
      liveSocket.connect()

      window.liveSocket = liveSocket
      """

      {status, updated_code} = Patcher.patch_code(code, Patches.js_hooks())

      assert updated_code == code
      assert status == :cannot_patch
    end
  end

  describe "add_ignore_js_hooks_to_gitignore" do
    test "add entry to ignore generated JS hook files in .gitignore" do
      code = """
      # Ignore assets that are produced by build tools.
      /priv/static/assets/
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_ignore_js_hooks_to_gitignore())

      assert updated_code == """
             # Ignore assets that are produced by build tools.
             /priv/static/assets/

             # Ignore generated js hook files for components
             assets/js/_hooks/
             """
    end

    test "trim spaces at the end so we can have a single line before the appended code" do
      code = """
      # Ignore assets that are produced by build tools.
      /priv/static/assets/


      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.add_ignore_js_hooks_to_gitignore())

      assert updated_code == """
             # Ignore assets that are produced by build tools.
             /priv/static/assets/

             # Ignore generated js hook files for components
             assets/js/_hooks/
             """
    end

    test "don't apply it if already patched" do
      code = """
      # Ignore assets that are produced by build tools.
      /priv/static/assets/

      # Ignore generated js hook files for components
      assets/js/_hooks/
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.add_ignore_js_hooks_to_gitignore())
    end
  end

  describe "patch_config_error_tag" do
    test "add `config :surface, :components` with the ErrorTag config" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.config_error_tag(MyAppWeb))

      assert updated_code == ~S"""
             import Config

             # Use Jason for JSON parsing in Phoenix
             config :phoenix, :json_library, Jason

             config :surface, :components, [
               {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
             ]

             # Import environment specific config. This must remain at the bottom
             # of this file so it overrides the configuration defined above.
             import_config "#{config_env()}.exs"
             """
    end

    test "append the ErrorTag config, if `config :surface, :components` elready exists" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      config :surface, :components, [
        {Surface.Components.Markdown, default_class: "content"}
      ]

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      {:patched, updated_code} = Patcher.patch_code(code, Patches.config_error_tag(MyAppWeb))

      assert updated_code == ~S"""
             import Config

             # Use Jason for JSON parsing in Phoenix
             config :phoenix, :json_library, Jason

             config :surface, :components, [
               {Surface.Components.Markdown, default_class: "content"},
               {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
             ]

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

      config :surface, :components, [
        {Surface.Components.Markdown, default_class: "content"},
        {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
      ]

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, Patches.config_error_tag(MyAppWeb))
    end
  end
end
