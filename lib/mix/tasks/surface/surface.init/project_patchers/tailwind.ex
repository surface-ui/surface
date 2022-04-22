defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Tailwind do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.ExPatcher
  alias Mix.Tasks.Surface.Init.ProjectPatcher
  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def file_patchers(%{tailwind: true} = assigns) do
    %{context_app: context_app, web_module: web_module} = assigns

    %{
      "mix.exs" => [
        add_tailwind_to_mix_deps()
      ],
      "config/config.exs" => [
        configure_tailwind()
      ],
      "config/dev.exs" => [
        add_tailwind_watcher_to_endpoint_config(context_app, web_module)
      ],
      "assets/js/app.js" => [
        remove_import_app_css()
      ],
      "assets/css/app.css" => [
        add_tailwind_directives()
      ]
    }
  end

  def file_patchers(_assigns), do: []

  @impl true
  def create_files(%{tailwind: true} = assigns) do
    ProjectPatcher.create_files(assigns, [
      {"tailwind/tailwind.config.js", "assets/"}
    ])
  end

  def create_files(_assigns), do: []

  def add_tailwind_to_mix_deps() do
    %{
      name: "Add `tailwind` dependency",
      update_deps: [:tailwind],
      patch: &FilePatchers.MixExs.add_dep(&1, ":tailwind", ~S["~> 0.1", runtime: Mix.env() == :dev]),
      instructions: """
      Add `tailwind` to the list of dependencies in `mix.exs`.

      # Example

      ```
      def deps do
        [
          {:tailwind, "~> 0.1", runtime: Mix.env() == :dev}
        ]
      end
      ```
      """
    }
  end

  def update_alias_assets_deploy_to_run_tailwind() do
    %{
      name: "Update alias `assets.deploy` to run `tailwind default --minify`",
      patch:
        &FilePatchers.MixExs.update_alias(
          &1,
          :"assets.deploy",
          ~S(["tailwind default --minify", "esbuild default --minify", "phx.digest"]),
          "tailwind",
          fn patcher ->
            ExPatcher.prepend_list_item(patcher, ~S("tailwind default --minify"))
          end
        ),
      instructions: """
      Update alias `assets.deploy` to also run `tailwind default --minify` in `mix.exs`.

      # Example

      ```
      defp aliases do
        [
          "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
        ]
      ]
      ```
      """
    }
  end

  def configure_tailwind do
    %{
      name: "Configure tailwind",
      patch:
        &FilePatchers.Config.add_root_config(&1, :tailwind, """
        config :tailwind,
          version: "3.0.23",
          default: [
            args: ~w(
              --config=tailwind.config.js
              --input=css/app.css
              --output=../priv/static/assets/app.css
            ),
            cd: Path.expand("../assets", __DIR__)
          ]\
        """),
      instructions: """
      Update your `config/config.exs` to set up tailwind.

      # Example

      ```
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
      ```
      """
    }
  end

  def add_tailwind_watcher_to_endpoint_config(context_app, web_module) do
    %{
      name: "Add the tailwind watcher",
      patch:
        &FilePatchers.Phoenix.add_watcher_to_endpoint_config(
          &1,
          :tailwind,
          "{Tailwind, :install_and_run, [:default, ~w(--watch)]}",
          "tailwind",
          context_app,
          web_module
        ),
      instructions: """
      Add the tailwind watcher

      # Example

      ```
      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          esbuild: ...,
          tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
        ]
      ```
      """
    }
  end

  def remove_import_app_css() do
    %{
      name: "Remove importing app.css in app.js",
      instructions: "",
      patch: [
        &FilePatchers.Text.remove_text(
          &1,
          """
          // We import the CSS which is extracted to its own file by esbuild.
          // Remove this line if you add a your own CSS build pipeline (e.g postcss).
          import "../css/app.css"

          """
        )
      ]
    }
  end

  def add_tailwind_directives() do
    %{
      name: "Add tailwind directives to app.css",
      instructions: "",
      patch:
        &FilePatchers.Text.prepend_text(
          &1,
          """
          @tailwind base;
          @tailwind components;
          @tailwind utilities;\
          """,
          "@tailwind"
        )
    }
  end
end
