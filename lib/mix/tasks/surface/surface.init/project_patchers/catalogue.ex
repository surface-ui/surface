defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Catalogue do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def specs(%{catalogue: true, demo: true} = assigns) do
    %{web_module: web_module} = assigns

    web_folder = web_module |> inspect() |> Macro.underscore()
    dest = Path.join(["priv/catalogue/", web_folder, "components"])

    patches(assigns) ++
      [
        {:create, "demo/card_examples.ex", dest},
        {:create, "demo/card_playground.ex", dest}
      ]
  end

  def specs(%{catalogue: true} = assigns) do
    patches(assigns)
  end

  def specs(_assigns), do: []

  def catalogue_requirement do
    ~S("~> 0.6.3")
  end

  defp patches(assigns) do
    %{context_app: context_app, web_module: web_module, web_path: web_path} = assigns

    [
      {:patch, "mix.exs",
       [
         add_surface_catalogue_to_mix_deps(),
         configure_catalogue_in_mix_exs()
       ]},
      {:patch, "config/config.exs",
       [
         configure_catalogue_esbuild()
       ]},
      {:patch, "config/dev.exs",
       [
         add_catalogue_live_reload_pattern_to_endpoint_config(context_app, web_module),
         add_catalogue_esbuild_watcher_to_endpoint_config(context_app, web_module)
       ]},
      {:patch, "#{web_path}/router.ex",
       [
         configure_catalogue_route(web_module)
       ]}
    ]
  end

  def add_surface_catalogue_to_mix_deps do
    %{
      name: "Add `surface_catalogue` dependency",
      patch: &FilePatchers.MixExs.add_dep(&1, ":surface_catalogue", catalogue_requirement()),
      update_deps: [:surface_catalogue],
      instructions: """
      Add `surface_catalogue` to the list of dependencies in `mix.exs`.

      # Example

      ```
      def deps do
        [
          {:surface_catalogue, #{catalogue_requirement()}}
        ]
      end
      ```
      """
    }
  end

  def configure_catalogue_in_mix_exs do
    %{
      name: "Configure `elixirc_paths` for the catalogue",
      patch: [
        &FilePatchers.MixExs.add_elixirc_paths_entry(
          &1,
          ":dev",
          ~S|["lib"] ++ catalogues()|,
          "catalogues()"
        ),
        &FilePatchers.MixExs.update_elixirc_paths_entry(
          &1,
          ":test",
          fn code -> "#{code} ++ catalogues()" end,
          "catalogues()"
        ),
        &FilePatchers.MixExs.append_def(&1, :catalogues, """
          [
            "priv/catalogue"
          ]\
        """)
      ],
      instructions: """
      If you want to access examples and playgrounds for components, edit your `mix.exs` file,
      adding a new entry for `elixirc_paths` along with a `catalogues` function listing the
      catalogues you want to be loaded.

      # Example

      ```
      defp elixirc_paths(:dev), do: ["lib"] ++ catalogues()
      defp elixirc_paths(:test), do: ["lib"] ++ catalogues()

      ...

      def catalogues do
        [
          "priv/catalogue"
        ]
      end
      """
    }
  end

  def configure_catalogue_esbuild do
    %{
      name: "Configure esbuild for the catalogue",
      patch:
        &FilePatchers.Phoenix.add_esbuild_entry_to_config(&1, :catalogue, """
        [
            args: ~w(../deps/surface_catalogue/assets/js/app.js --bundle --target=es2016 --minify --outdir=../priv/static/assets/catalogue),
            cd: Path.expand("../assets", __DIR__),
            env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
          ]\
        """),
      instructions: """
      Update your `config/config.exs` to set up a esbuild entry fot the catalogue.

      # Example

      ```
      config :esbuild,
        ...
        catalogue: [
          args: ~w(../deps/surface_catalogue/assets/js/app.js --bundle --target=es2016 --minify --outdir=../priv/static/assets/catalogue),
          cd: Path.expand("../assets", __DIR__),
          env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
        ]
      ```
      """
    }
  end

  def configure_catalogue_route(web_module) do
    %{
      name: "Configure catalogue route",
      patch: [
        &FilePatchers.Phoenix.add_import_to_router(&1, Surface.Catalogue.Router, web_module),
        &FilePatchers.Phoenix.append_route(&1, "/catalogue", web_module, """
        if Mix.env() == :dev do
          scope "/" do
            pipe_through :browser
            surface_catalogue "/catalogue"
          end
        end\
        """)
      ],
      instructions: """
      Update your `router.ex` configuration so the catalogue can be available at `/catalogue`.

      # Example

      ```
      import Surface.Catalogue.Router

      ...

      if Mix.env() == :dev do
        scope "/" do
          pipe_through :browser
          surface_catalogue "/catalogue"
        end
      end
      ```
      """
    }
  end

  def add_catalogue_live_reload_pattern_to_endpoint_config(context_app, web_module) do
    %{
      name: "Update patterns in :reload_patterns to reload catalogue files",
      patch:
        &FilePatchers.Phoenix.add_live_reload_pattern_to_endpoint_config(
          &1,
          ~S|~r"priv/catalogue/.*(ex)$"|,
          "catalogue",
          context_app,
          web_module
        ),
      instructions: """
      Update the :reload_patterns entry to include catalogue files.

      # Example

      ```
      config :my_app, MyAppWeb.Endpoint,
        live_reload: [
          patterns: [
            ~r"priv/catalogue/.*(ex)$"
            ...
          ]
        ]
      ```
      """
    }
  end

  def add_catalogue_esbuild_watcher_to_endpoint_config(context_app, web_module) do
    %{
      name: "Add esbuild watcher for :catalogue",
      file: "config/dev.exs",
      patch:
        &FilePatchers.Phoenix.add_watcher_to_endpoint_config(
          &1,
          :esbuild,
          "{Esbuild, :install_and_run, [:catalogue, ~w(--sourcemap=inline --watch)]}",
          "catalogue",
          context_app,
          web_module
        ),
      instructions: """
      Add a new esbuild watcher for the :catalogue entry.

      # Example

      ```
      config :my_app, MyAppWeb.Endpoint,
        watchers: [
          esbuild: ...,
          esbuild: {Esbuild, :install_and_run, [:catalogue, ~w(--sourcemap=inline --watch)]},
        ]
      ```
      """
    }
  end
end
