defmodule Mix.Tasks.Surface.Init.ProjectPatchers.ScopedCSS do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def specs(%{scoped_css: true}) do
    [
      {:patch, "assets/css/app.css", [add_import_components()]},
      {:patch, ".gitignore", [add_ignore_components_css_to_gitignore()]}
    ]
  end

  def specs(_assigns), do: []

  def add_import_components() do
    %{
      name: "Add CSS file for components to app.css",
      instructions: "",
      patch:
        &FilePatchers.Text.prepend_text(
          &1,
          """
          /* Import scoped CSS rules for components */
          @import "./_components.css";\
          """,
          ~S(@import "./_components.css";)
        )
    }
  end

  def add_ignore_components_css_to_gitignore() do
    %{
      name: "Ignore generated CSS file for components",
      instructions: "",
      patch:
        &FilePatchers.Text.append_line(
          &1,
          """
          # Ignore generated CSS file for components
          assets/css/_components.css
          """,
          "assets/css/_components.css"
        )
    }
  end
end
