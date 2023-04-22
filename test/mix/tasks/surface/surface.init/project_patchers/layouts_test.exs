defmodule Mix.Tasks.Surface.Init.ProjectPatchers.LayoutsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Layouts

  describe "add_embed_sface_calls_to_layouts" do
    test "add layout config to view macro" do
      code = """
      defmodule MyAppWeb.Layouts do
        use MyAppWeb, :html

        embed_templates "layouts/*"
      end
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_embed_sface_calls_to_layouts(MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb.Layouts do
               use MyAppWeb, :html

               embed_templates "layouts/*"
               embed_sface "layouts/root.sface"
               embed_sface "layouts/app.sface"
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb.Layouts do
        use MyAppWeb, :html

        embed_templates "layouts/*"
        embed_sface "layouts/root.sface"
      end
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_embed_sface_calls_to_layouts(MyAppWeb))
    end
  end
end
