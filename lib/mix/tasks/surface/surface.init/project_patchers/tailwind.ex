defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Tailwind do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def specs(_assigns) do
    [
      {:patch, "assets/tailwind.config.js", [add_sface_patterns_to_tailwind_config_js()]},
    ]
  end

  def add_sface_patterns_to_tailwind_config_js() do
    %{
      name: "Add surface files to tailwind.config.js content section",
      instructions: "",
      patch:
        &FilePatchers.Text.replace_text(
          &1,
          """
            content: [
              "./js/**/*.js",
              "../lib/*_web.ex",
              "../lib/*_web/**/*.*ex"
            ],
          """,
          """
            content: [
              "./js/**/*.js",
              "../lib/*_web.ex",
              "../lib/*_web/**/*.*ex",
              "../lib/*_web/**/*.sface",
              "../priv/catalogue/**/*.{ex,sface}"
            ],
          """,
          "../lib/*_web/**/*.sface"
        )
    }
  end
end
