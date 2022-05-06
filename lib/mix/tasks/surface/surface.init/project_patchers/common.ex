defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Common do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def specs(assigns) do
    %{
      context_app: context_app,
      web_module: web_module,
      web_module_path: web_module_path,
      web_path: web_path
    } = assigns

    [
      {:patch, "config/dev.exs",
       [
         add_surface_live_reload_pattern_to_endpoint_config(context_app, web_module, web_path),
         add_surface_live_reload_template_pattern_to_endpoint_config(context_app, web_module, web_path)
       ]},
      {:patch, web_module_path,
       [
         add_import_surface_to_view_macro(web_module)
       ]}
    ]
  end

  def add_surface_live_reload_pattern_to_endpoint_config(context_app, web_module, web_path) do
    %{
      name: "Update patterns in :reload_patterns",
      patch:
        &FilePatchers.Phoenix.replace_live_reload_pattern_in_endpoint_config(
          &1,
          ~s[~r"#{web_path}/(live|views)/.*(ex)$"],
          ~s[~r"#{web_path}/(live|views|components)/.*(ex|sface|js)$"],
          "ex|sface|js",
          context_app,
          web_module
        ),
      instructions: """
      Update the :reload_patterns entry to include surface related files.

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

  def add_surface_live_reload_template_pattern_to_endpoint_config(context_app, web_module, web_path) do
    %{
      name: "Update template patterns in :reload_patterns",
      patch:
        &FilePatchers.Phoenix.replace_live_reload_pattern_in_endpoint_config(
          &1,
          ~s[~r"#{web_path}/templates/.*(eex)$"],
          ~s[~r"#{web_path}/templates/.*(eex|sface)$"],
          "eex|sface",
          context_app,
          web_module
        ),
      instructions: """
      Update the :reload_patterns template entry to include surface related files.

      # Example

      ```
      config :my_app, MyAppWeb.Endpoint,
        live_reload: [
          patterns: [
            ~r"lib/my_app_web/templates/.*(eex|sface)$"
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
      patch: &FilePatchers.Phoenix.add_import_to_view_macro(&1, Surface, web_module),
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
end
