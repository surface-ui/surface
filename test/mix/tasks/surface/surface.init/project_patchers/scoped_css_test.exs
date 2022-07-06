defmodule Mix.Tasks.Surface.Init.ProjectPatchers.ScopedCSSTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.ScopedCSS

  describe "add_import_components" do
    test "Add import components" do
      code = """
      /* This file is for your main application CSS */
      @import "./phoenix.css";

      /* Alerts and form errors used by phx.new */
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_import_components())

      assert updated_code == """
             /* Import scoped CSS rules for components */
             @import "./_components.css";

             /* This file is for your main application CSS */
             @import "./phoenix.css";

             /* Alerts and form errors used by phx.new */
             """
    end

    test "don't apply it if already patched" do
      code = """
      /* Import scoped CSS rules for components */
      @import "./_components.css";

      /* This file is for your main application CSS */
      @import "./phoenix.css";
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_import_components())
    end
  end

  describe "add_ignore_components_css_to_gitignore" do
    test "add entry to ignore generated CSS file for components in .gitignore" do
      code = """
      # Ignore assets that are produced by build tools.
      /priv/static/assets/
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_ignore_components_css_to_gitignore())

      assert updated_code == """
             # Ignore assets that are produced by build tools.
             /priv/static/assets/

             # Ignore generated CSS file for components
             assets/css/_components.css
             """
    end

    test "don't apply it if already patched" do
      code = """
      # Ignore assets that are produced by build tools.
      /priv/static/assets/

      # Ignore generated CSS file for components
      assets/css/_components.css
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, add_ignore_components_css_to_gitignore())
    end
  end
end
