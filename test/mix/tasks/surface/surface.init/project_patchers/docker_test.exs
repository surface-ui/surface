defmodule Mix.Tasks.Surface.Init.ProjectPatchers.DockerTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Docker

  describe "swap_assets_deploy_with_compile" do
    test "Add surface files to tailwind.config.js content section" do
      code = """
      # compile assets
      RUN mix assets.deploy

      # Compile the release
      RUN mix compile
      """

      {:patched, updated_code} = Patcher.patch_code(code, swap_assets_deploy_with_compile())

      assert updated_code == """
             # Compile the release
             RUN mix compile

             # compile assets
             RUN mix assets.deploy
             """
    end

    test "don't apply it if already patched" do
      code = """
      # Compile the release
      RUN mix compile

      # compile assets
      RUN mix assets.deploy
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(code, swap_assets_deploy_with_compile())
    end
  end
end
