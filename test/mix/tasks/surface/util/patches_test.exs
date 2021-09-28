defmodule Mix.Tasks.Surface.Init.PatchesTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.ExPatcher
  alias Mix.Tasks.Surface.Init.Patches

  defp convert_patch_result(%ExPatcher{code: code, result: result}) do
    {result, code}
  end

  defp convert_patch_result(result) do
    result
  end

  def patch_code(code, patch_spec) do
    code
    |> patch_spec.patch.()
    |> convert_patch_result()
  end

  describe "patch_mix_compilers" do
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

      {:patched, updated_code} = patch_code(code, Patches.mix_compilers())

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

      assert {:already_patched, ^code} = patch_code(code, Patches.mix_compilers())
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

      assert {:maybe_already_patched, ^code} = patch_code(code, Patches.mix_compilers())
    end
  end

  describe "patch_web_view_config" do
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

      {:patched, updated_code} = patch_code(code, Patches.web_view_config(MyAppWeb))

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

      assert {:already_patched, ^code} = patch_code(code, Patches.web_view_config(MyAppWeb))
    end
  end

  describe "patch_formatter_surface_inputs" do
    test "add :surface_inputs" do
      code = """
      [
        import_deps: [:phoenix, :ecto],
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
      ]
      """

      {:patched, updated_code} = patch_code(code, Patches.formatter_surface_inputs())

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

      assert {:already_patched, ^code} = patch_code(code, Patches.formatter_surface_inputs())
    end
  end

  describe "patch_formatter_import_deps" do
    test "add :surface to :import_deps" do
      code = """
      [
        import_deps: [:phoenix, :ecto],
        inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
      ]
      """

      {:patched, updated_code} = patch_code(code, Patches.formatter_import_deps())

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

      assert {:already_patched, ^code} = patch_code(code, Patches.formatter_import_deps())
    end
  end

  describe "patch_endpoint_config_reloadable_compilers" do
    test "add reloadable_compilers if there's no :reloadable_compilers key" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyAppWeb.Endpoint,
        live_reload: [
          patterns: []
        ]
      """

      {:patched, updated_code} = patch_code(code, Patches.endpoint_config_reloadable_compilers(:my_app, MyAppWeb))

      assert updated_code == """
             import Config

             # Watch static and templates for browser reloading.
             config :my_app, MyAppWeb.Endpoint,
               reloadable_compilers: [:phoenix, :elixir, :surface],
               live_reload: [
                 patterns: []
               ]
             """
    end

    test "add :surface to reloadable_compilers if :reloadable_compilers already exists" do
      code = """
      import Config

      # Watch static and templates for browser reloading.
      config :my_app, MyAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir],
        live_reload: [
          patterns: []
        ]
      """

      {:patched, updated_code} = patch_code(code, Patches.endpoint_config_reloadable_compilers(:my_app, MyAppWeb))

      assert updated_code == """
             import Config

             # Watch static and templates for browser reloading.
             config :my_app, MyAppWeb.Endpoint,
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
      config :my_app, MyAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir, :surface],
        live_reload: [
          patterns: []
        ]
      """

      assert {:already_patched, ^code} =
               patch_code(code, Patches.endpoint_config_reloadable_compilers(:my_app, MyAppWeb))
    end
  end

  describe "patch_endpoint_config_live_reload_patterns" do
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
        patch_code(code, Patches.endpoint_config_live_reload_patterns(:my_app, MyAppWeb, "lib/my_app_web"))

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
               patch_code(code, Patches.endpoint_config_live_reload_patterns(:my_app, MyAppWeb, "lib/my_app_web"))
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

      {:patched, updated_code} = patch_code(code, Patches.js_hooks())

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

      assert {:already_patched, ^code} = patch_code(code, Patches.js_hooks())
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

      assert {:file_modified, ^code} = patch_code(code, Patches.js_hooks())
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

      {:patched, updated_code} = patch_code(code, Patches.config_error_tag(MyAppWeb))

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

      {:patched, updated_code} = patch_code(code, Patches.config_error_tag(MyAppWeb))

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

      assert {:already_patched, ^code} = patch_code(code, Patches.config_error_tag(MyAppWeb))
    end
  end
end
