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
      {:patch, "mix.exs", [add_surface_to_mix_compilers()]},
      {:patch, "config/dev.exs",
       [
         add_surface_live_reload_pattern_to_endpoint_config(context_app, web_module, web_path)
       ]},
      {:patch, web_module_path,
       [
         add_import_surface_to_html_macro(web_module),
         add_surface_live_view_macro(web_module)
       ]}
    ]
  end

  def add_surface_to_mix_compilers() do
    %{
      name: "Add :surface to compilers",
      patch: &FilePatchers.MixExs.add_compiler(&1, ":surface"),
      instructions: """
      Append `:surface` to the list of compilers.

      # Example

      ```
      def project do
        [
          ...
          compilers: Mix.compilers() ++ [:surface],
          ...
        ]
      end
      ```
      """
    }
  end

  def add_surface_live_reload_pattern_to_endpoint_config(context_app, web_module, web_path) do
    %{
      name: "Update patterns in :reload_patterns",
      patch:
        &FilePatchers.Phoenix.replace_live_reload_pattern_in_endpoint_config(
          &1,
          ~s[~r"#{web_path}/(controllers|live|components)/.*(ex|heex)$"],
          ~s[~r"#{web_path}/(controllers|live|components)/.*(ex|heex|sface|js)$"],
          "ex|heex|sface|js",
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
            ~r"lib/my_app_web/(controllers|live|components)/.*(ex|heex|sface|js)$",
            ...
          ]
        ]
      ```
      """
    }
  end

  def add_import_surface_to_html_macro(web_module) do
    %{
      name: "Add `import Surface` to html config",
      patch: &FilePatchers.Phoenix.add_import_to_html_macro(&1, Surface, web_module),
      instructions: """
      In order to have `~F` available for any Phoenix cotroller, you can import surface.

      # Example

      ```elixir
      def html do
        quote do
          ...
          import Surface
        end
      end
      ```
      """
    }
  end

  def add_surface_live_view_macro(web_module) do
    %{
      name: "Add `surface_live_view` macro",
      patch:
        &FilePatchers.Phoenix.append_def_to_web_module(&1, :surface_live_view, """
          quote do
            use Surface.LiveView,
              layout: {#{inspect(web_module)}.Layouts, :app}

            unquote(html_helpers())
          end\
        """),
      instructions: """
      Create a `surface_live_view` macro so it includes the default phoenix helpers and layouts
      when using `use #{inspect(web_module)}, :surface_live_view`.

      # Example

      ```
      def surface_live_view do
        quote do
          use Surface.LiveView,
            layout: {#{inspect(web_module)}.Layouts, :app}

          unquote(html_helpers())
        end
      end
      """
    }
  end
end
