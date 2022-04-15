defmodule Mix.Tasks.Surface.Init.Patches do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.Patchers

  # Common patches

  def add_surface_live_reload_pattern_to_endpoint_config(context_app, web_module, web_path) do
    %{
      name: "Update patterns in :reload_patterns",
      patch:
        &Patchers.Phoenix.replace_live_reload_pattern_in_endpoint_config(
          &1,
          ~s[~r"#{web_path}/(live|views)/.*(ex)$"],
          ~s[~r"#{web_path}/(live|views|components)/.*(ex|sface|js)$"],
          "sface",
          context_app,
          web_module
        ),
      instructions: """
      Update the :reload_patterns entry to include surface-related files.

      # Example

      ```
      config :my_app, MyAppWeb.Endpoint,
        live_reload: [
          patterns: [
            ~r"lib/my_app_web/(live|views|components)/.*(ex|sface|js)$",
            ...
          ]
        ]
      ```
      """
    }
  end

  def add_import_surface_to_view_macro(web_module) do
    %{
      name: "Add `import Surface` to view config",
      patch: &Patchers.Phoenix.add_import_to_view_macro(&1, Surface, web_module),
      instructions: """
      In order to have `~F` available for any Phoenix view, you can import surface.

      # Example

      ```elixir
      def view do
        quote do
          ...
          import Surface
        end
      end
      ```
      """
    }
  end

  # Formatter patches

  def add_surface_formatter_to_mix_deps() do
    %{
      name: "Add `surface_formatter` dependency",
      update_deps: [:surface_formatter],
      patch: &Patchers.MixExs.add_dep(&1, ":surface_formatter", ~S("~> 0.6.0")),
      instructions: """
      Add `surface_formatter` to the list of dependencies in `mix.exs`.

      # Example

      ```
      def deps do
        [
          {:surface_formatter, "~> 0.6.0"}
        ]
      end
      ```
      """
    }
  end

  def add_surface_inputs_to_formatter_config() do
    %{
      name: "Add file extensions to :surface_inputs",
      patch: &Patchers.Formatter.add_config(&1, :surface_inputs, ~S(["{lib,test}/**/*.{ex,exs,sface}"])),
      instructions: """
      In case you'll be using `mix format`, make sure you add the required file patterns
      to your `.formatter.exs` file.

      # Example

      ```
      [
        surface_inputs: ["{lib,test}/**/*.{ex,exs,sface}"],
        ...
      ]
      ```
      """
    }
  end

  def add_sface_files_to_inputs_in_formatter_config() do
    %{
      name: "Add sface files to :inputs",
      patch: &Patchers.Formatter.add_input(&1, ~S("{lib,test}/**/*.sface")),
      instructions: """
      In case you'll be using `mix format`, make sure you add the required file patterns
      to your `.formatter.exs` file.

      # Example

      ```
      [
        inputs: ["{lib,test}/**/*.sface", ...],
        ...
      ]
      ```
      """
    }
  end

  def add_surface_to_import_deps_in_formatter_config() do
    %{
      name: "Add :surface to :import_deps",
      patch: &Patchers.Formatter.add_import_dep(&1, ":surface"),
      instructions: """
      In case you'll be using `mix format`, make sure you add `:surface` to the `import_deps`
      configuration in your `.formatter.exs` file.

      # Example

      ```
      [
        import_deps: [:ecto, :phoenix, :surface],
        ...
      ]
      ```
      """
    }
  end

  def add_formatter_plugin_to_formatter_config() do
    %{
      name: "Add Surface.Formatter.Plugin to :plugins",
      patch: &Patchers.Formatter.add_plugin(&1, "Surface.Formatter.Plugin"),
      instructions: """
      In case you'll be using `mix format`, make sure you add `Surface.Formatter.Plugin`
      to the `plugins` in your `.formatter.exs` file.

      # Example

      ```
      [
        plugins: [Surface.Formatter.Plugin],
        ...
      ]
      ```
      """
    }
  end

  # Catalogue patches

  def add_surface_catalogue_to_mix_deps() do
    %{
      name: "Add `surface_catalogue` dependency",
      update_deps: [:surface_catalogue],
      patch: &Patchers.MixExs.add_dep(&1, ":surface_catalogue", ~S("~> 0.2.0")),
      instructions: """
      Add `surface_catalogue` to the list of dependencies in `mix.exs`.

      # Example

      ```
      def deps do
        [
          {:surface_catalogue, "~> 0.2.0"}
        ]
      end
      ```
      """
    }
  end

  def configure_catalogue_in_mix_exs() do
    %{
      name: "Configure `elixirc_paths` for the catalogue",
      patch: [
        &Patchers.MixExs.add_elixirc_paths_entry(&1, ":dev", ~S|["lib"] ++ catalogues()|, "catalogues()"),
        &Patchers.MixExs.append_def(&1, "catalogues", """
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

      ...

      def catalogues do
        [
          "priv/catalogue"
        ]
      end
      """
    }
  end

  def configure_catalogue_route(web_module) do
    %{
      name: "Configure catalogue route",
      patch: [
        &Patchers.Phoenix.add_import_to_router(&1, Surface.Catalogue.Router, web_module),
        &Patchers.Phoenix.append_route(&1, "/catalogue", web_module, """
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

  def configure_demo_route(web_module) do
    %{
      name: "Configure demo route",
      patch: &Patchers.Phoenix.append_route_to_main_scope(&1, ~S("/demo"), web_module, ~S(live "/demo", Demo)),
      instructions: """
      Update your `router.ex` configuration so the demo can be available at `/demo`.

      # Example

      ```
      scope "/", MyAppWeb do
        pipe_through :browser

        live "/demo", Demo
      end
      ```
      """
    }
  end

  def add_catalogue_live_reload_pattern_to_endpoint_config(context_app, web_module) do
    %{
      name: "Update patterns in :reload_patterns to reload catalogue files",
      patch:
        &Patchers.Phoenix.add_live_reload_pattern_to_endpoint_config(
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

  # ErrorTag patches

  def config_error_tag(web_module) do
    name = "Configure the ErrorTag component to use Gettext"

    instructions = """
    Set the `default_translator` option to the project's `ErrorHelpers.translate_error/1` function,
    which should be using Gettext for translations.

    # Example

    ```
    config :surface, :components, [
      ...
      {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
    ]
    ```
    """

    patch =
      &Patchers.Component.add_config(
        &1,
        "Surface.Components.Form.ErrorTag",
        "default_translator: {#{inspect(web_module)}.ErrorHelpers, :translate_error}"
      )

    %{name: name, instructions: instructions, patch: patch}
  end

  # JS hooks patches

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
        &Patchers.JS.replace_line_text(
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
