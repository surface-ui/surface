defmodule Mix.Tasks.Surface.Init.ProjectPatchers.JSHooksTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.JsHooks

  describe "patch_js_hooks" do
    test "configure JS hooks" do
      code = """
      // We import the CSS which is extracted to its own file by esbuild.
      import "../css/app.css"

      import {LiveSocket} from "phoenix_live_view"
      import topbar from "../vendor/topbar"

      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
      let liveSocket = new LiveSocket("/live", Socket, {
        longPollFallbackMs: 2500,
        params: {_csrf_token: csrfToken}
      })

      // connect if there are any LiveViews on the page
      liveSocket.connect()

      window.liveSocket = liveSocket
      """

      {_patched, updated_code} = Patcher.patch_code(code, js_hooks())

      assert updated_code == """
             // We import the CSS which is extracted to its own file by esbuild.
             import "../css/app.css"

             import {LiveSocket} from "phoenix_live_view"
             import topbar from "../vendor/topbar"
             import Hooks from "./_hooks"

             let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
             let liveSocket = new LiveSocket("/live", Socket, {
               longPollFallbackMs: 2500,
               hooks: Hooks,
               params: {_csrf_token: csrfToken}
             })

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
      let liveSocket = new LiveSocket("/live", Socket, {
        longPollFallbackMs: 2500,
        hooks: Hooks,
        params: {_csrf_token: csrfToken}
      })

      // connect if there are any LiveViews on the page
      liveSocket.connect()

      window.liveSocket = liveSocket
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, js_hooks())
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

      {status, updated_code} = Patcher.patch_code(code, js_hooks())

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

      {:patched, updated_code} = Patcher.patch_code(code, add_ignore_js_hooks_to_gitignore())

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

      {:patched, updated_code} = Patcher.patch_code(code, add_ignore_js_hooks_to_gitignore())

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

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_ignore_js_hooks_to_gitignore())
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
          add_surface_to_reloadable_compilers_in_endpoint_config(:my_app, MyTestAppWeb)
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
          add_surface_to_reloadable_compilers_in_endpoint_config(:my_app, MyTestAppWeb)
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
                 add_surface_to_reloadable_compilers_in_endpoint_config(:my_app, MyTestAppWeb)
               )
    end
  end
end
