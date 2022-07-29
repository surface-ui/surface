defmodule Mix.Tasks.Surface.Init.ProjectPatchers.CommonTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Common

  describe "add_surface_to_mix_compilers" do
    test "add :surface to compilers" do
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
            ~r"lib/my_app_web/(live|views)/.*(ex)$",
            ~r"lib/my_app_web/templates/.*(eex)$"
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
                 add_surface_live_reload_pattern_to_endpoint_config(:my_app, MyAppWeb, "lib/my_app_web")
               )
    end
  end

  describe "add_surface_live_reload_template_pattern_to_endpoint_config" do
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
          add_surface_live_reload_template_pattern_to_endpoint_config(:my_app, MyAppWeb, "lib/my_app_web")
        )

      assert updated_code == """
             import Config

             # Watch static and templates for browser reloading.
             config :my_app, MyAppWeb.Endpoint,
               reloadable_compilers: [:phoenix, :elixir, :surface],
               live_reload: [
                 patterns: [
                   ~r"lib/my_app_web/(live|views)/.*(ex)$",
                   ~r"lib/my_app_web/templates/.*(eex|sface)$"
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
            ~r"lib/my_app_web/(live|views)/.*(ex)$",
            ~r"lib/my_app_web/templates/.*(eex|sface)$"
          ]
        ]
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(
                 code,
                 add_surface_live_reload_template_pattern_to_endpoint_config(:my_app, MyAppWeb, "lib/my_app_web")
               )
    end
  end

  describe "add_import_surface_to_view_macro" do
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

      {:patched, updated_code} = Patcher.patch_code(code, add_import_surface_to_view_macro(MyAppWeb))

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

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_import_surface_to_view_macro(MyAppWeb))
    end
  end
end
