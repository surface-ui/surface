defmodule Mix.Tasks.Surface.Init.ProjectPatchers.JsHooks do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def specs(%{js_hooks: true} = assigns) do
    %{context_app: context_app, web_module: web_module} = assigns

    [
      {:patch, "assets/js/app.js", [js_hooks()]},
      {:patch, "config/dev.exs",
       [
         add_surface_to_reloadable_compilers_in_endpoint_config(context_app, web_module)
       ]},
      {:patch, ".gitignore", [add_ignore_js_hooks_to_gitignore()]}
    ]
  end

  def specs(_assigns), do: []

  def add_surface_to_reloadable_compilers_in_endpoint_config(context_app, web_module) do
    %{
      name: "Add :surface to :reloadable_compilers",
      patch:
        &FilePatchers.Phoenix.add_reloadable_compiler_to_endpoint_config(&1, :surface, context_app, web_module),
      instructions: """
      Add :surface to the list of reloadable compilers.

      # Example

      ```
      config :my_app, MyAppWeb.Endpoint,
        reloadable_compilers: [:phoenix, :elixir, :surface],
        ...
      ```
      """
    }
  end

  def js_hooks() do
    %{
      name: "Configure components' JS hooks",
      instructions: """
      Import Surface components' hooks and pass them to `new LiveSocket(...)`.

      # Example

      ```JS
      import Hooks from "./_hooks"

      let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, ... })
      ```
      """,
      patch: [
        &FilePatchers.JS.add_import(&1, ~S[import Hooks from "./_hooks"]),
        &FilePatchers.Text.replace_line_text(
          &1,
          ~S[  params: {_csrf_token: csrfToken}],
          ~s[  hooks: Hooks,\n  params: {_csrf_token: csrfToken}]
        )
      ]
    }
  end

  def add_ignore_js_hooks_to_gitignore() do
    %{
      name: "Ignore generated JS hook files for components",
      instructions: "",
      patch:
        &FilePatchers.Text.append_line(
          &1,
          """
          # Ignore generated js hook files for components
          assets/js/_hooks/
          """,
          "assets/js/_hooks/"
        )
    }
  end
end
