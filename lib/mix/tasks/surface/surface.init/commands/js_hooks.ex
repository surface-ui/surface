defmodule Mix.Tasks.Surface.Init.Commands.JsHooks do
  alias Mix.Tasks.Surface.Init.Patchers

  @behaviour Mix.Tasks.Surface.Init.Command

  @impl true
  def file_patchers(%{js_hooks: true} = assigns) do
    %{context_app: context_app, web_module: web_module} = assigns

    %{
      "mix.exs" => [
        add_surface_to_mix_compilers()
      ],
      "assets/js/app.js" => [
        js_hooks()
      ],
      "config/dev.exs" => [
        add_surface_to_reloadable_compilers_in_endpoint_config(context_app, web_module)
      ],
      ".gitignore" => [
        add_ignore_js_hooks_to_gitignore()
      ]
    }
  end

  def file_patchers(_assigns), do: []

  @impl true
  def create_files(_assigns), do: []

  def add_surface_to_mix_compilers() do
    %{
      name: "Add :surface to compilers",
      patch: &Patchers.MixExs.add_compiler(&1, ":surface"),
      instructions: """
      Append `:surface` to the list of compilers.

      # Example

      ```
      def project do
        [
          ...
          compilers: [:gettext] ++ Mix.compilers() ++ [:surface],
          ...
        ]
      end
      ```
      """
    }
  end

  def add_surface_to_reloadable_compilers_in_endpoint_config(context_app, web_module) do
    %{
      name: "Add :surface to :reloadable_compilers",
      patch: &Patchers.Phoenix.add_reloadable_compiler_to_endpoint_config(&1, :surface, context_app, web_module),
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
        &Patchers.JS.add_import(&1, ~S[import Hooks from "./_hooks"]),
        &Patchers.Text.replace_line_text(
          &1,
          ~S[let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})],
          ~S[let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})]
        )
      ]
    }
  end

  def add_ignore_js_hooks_to_gitignore() do
    %{
      name: "Ignore generated JS hook files for components",
      instructions: "",
      patch:
        &Patchers.Text.append_line(
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
