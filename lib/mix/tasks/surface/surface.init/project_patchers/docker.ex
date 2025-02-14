defmodule Mix.Tasks.Surface.Init.ProjectPatchers.Docker do
  @moduledoc false

  alias Mix.Tasks.Surface.Init.FilePatchers

  @behaviour Mix.Tasks.Surface.Init.ProjectPatcher

  @impl true
  def specs(_assigns) do
    [
      {:patch, "Dockerfile", [swap_assets_deploy_with_compile()]}
    ]
  end

  def swap_assets_deploy_with_compile() do
    %{
      name: "Run mix compile before mix assets.deploy",
      ignore_when: [:file_not_found],
      instructions: """
      Update `Dockerfile` so that `mix compile` is called before `mix assets.deploy`.

      # Example

      ```
      # Compile the release
      RUN mix compile

      # compile assets
      RUN mix assets.deploy
      ```
      """,
      patch:
        &FilePatchers.Text.replace_text(
          &1,
          """
          # compile assets
          RUN mix assets.deploy

          # Compile the release
          RUN mix compile
          """,
          """
          # Compile the release
          RUN mix compile

          # compile assets
          RUN mix assets.deploy
          """,
          """
          # Compile the release
          RUN mix compile

          # compile assets
          RUN mix assets.deploy
          """
        )
    }
  end
end
