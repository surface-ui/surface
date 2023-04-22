defmodule Mix.Tasks.Surface.Init.ProjectPatchers.CommonTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Common

  describe "add_surface_to_mix_compilers" do
    test "add :compilers with :surface" do
      code = """
      defmodule MyApp.MixProject do
        use Mix.Project

        def project do
          [
            app: :my_app,
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

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_to_mix_compilers())

      assert updated_code == """
             defmodule MyApp.MixProject do
               use Mix.Project

               def project do
                 [
                   app: :my_app,
                   start_permanent: Mix.env() == :prod,
                   compilers: Mix.compilers() ++ [:surface]
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

    test "add :surface to compilers if :compilers is alredy present" do
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

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_to_mix_compilers())

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

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_to_mix_compilers())

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

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_surface_to_mix_compilers())
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
            ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
            ~r"priv/gettext/.*(po)$",
            ~r"lib/my_app_web/(controllers|live|components)/.*(ex|heex)$"
          ]
        ]
      """

      {:patched, updated_code} =
        Patcher.patch_code(
          code,
          add_surface_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb, "lib/my_app_web")
        )

      assert updated_code == """
             import Config

             # Watch static and templates for browser reloading.
             config :my_app, MyAppWeb.Endpoint,
               reloadable_compilers: [:phoenix, :elixir, :surface],
               live_reload: [
                 patterns: [
                   ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
                   ~r"priv/gettext/.*(po)$",
                   ~r"lib/my_app_web/(controllers|live|components)/.*(ex|heex|sface|js)$"
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
            ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
            ~r"lib/my_app_web/(controllers|live|components)/.*(ex|heex|sface|js)$",
            ~r"lib/my_app_web/templates/.*(eex)$"
          ]
        ]
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(
                 code,
                 add_surface_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb, "lib/my_app_web")
               )
    end
  end

  describe "add_import_surface_to_html_macro" do
    test "add import Surface" do
      code = """
      defmodule MyAppWeb do
        def html do
          quote do
            use Phoenix.Component

            # Import convenience functions from controllers
            import Phoenix.Controller,
              only: [get_csrf_token: 0, view_module: 1, view_template: 1]

            # Include general helpers for rendering HTML
            unquote(html_helpers())
          end
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_import_surface_to_html_macro(MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb do
               def html do
                 quote do
                   use Phoenix.Component

                   # Import convenience functions from controllers
                   import Phoenix.Controller,
                     only: [get_csrf_token: 0, view_module: 1, view_template: 1]

                   # Include general helpers for rendering HTML
                   unquote(html_helpers())
                   import Surface
                 end
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb do
        def html do
          quote do
            use Phoenix.Component

            # Import convenience functions from controllers
            import Phoenix.Controller,
              only: [get_csrf_token: 0, view_module: 1, view_template: 1]

            # Include general helpers for rendering HTML
            unquote(html_helpers())
            import Surface
          end
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_import_surface_to_html_macro(MyAppWeb))
    end
  end

  describe "add_surface_live_view_macro" do
    test "add surface_live_view macro" do
      code = """
      defmodule MyAppWeb do
        @doc \"""
        When used, dispatch to the appropriate controller/view/etc.
        \"""
        defmacro __using__(which) when is_atom(which) do
          apply(__MODULE__, which, [])
        end
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_surface_live_view_macro(MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb do
               @doc \"""
               When used, dispatch to the appropriate controller/view/etc.
               \"""
               defmacro __using__(which) when is_atom(which) do
                 apply(__MODULE__, which, [])
               end

               def surface_live_view do
                 quote do
                   use Surface.LiveView,
                     layout: {MyAppWeb.Layouts, :app}

                   unquote(html_helpers())
                 end
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb do
        defmacro __using__(which) when is_atom(which) do
          apply(__MODULE__, which, [])
        end

        def surface_live_view do
          quote do
            use Surface.LiveView,
              layout: {MyAppWeb.Layouts, :app}

            unquote(html_helpers())
          end
        end
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_surface_live_view_macro(MyAppWeb))
    end
  end
end
