defmodule Mix.Tasks.Surface.Init.ProjectPatchers.LayoutsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Layouts

  describe "add_layout_config_to_view_macro" do
    test "add layout config to view macro" do
      code = """
      defmodule MyAppWeb do
        def view do
          quote do
            use Phoenix.View,
              root: "lib/my_app_web/templates",
              namespace: MyAppWeb

            # Include shared imports and aliases for views
            unquote(view_helpers())
            import Surface
          end
        end
      end
      """

      {:patched, updated_code} =
        Patcher.patch_code(code, add_layout_config_to_view_macro("lib/my_app_web", MyAppWeb))

      assert updated_code == """
             defmodule MyAppWeb do
               def view do
                 quote do
                   use Phoenix.View,
                     root: "lib/my_app_web/templates",
                     namespace: MyAppWeb

                   # Include shared imports and aliases for views
                   unquote(view_helpers())
                   import Surface
                   use Surface.View, root: "lib/my_app_web/templates"
                 end
               end
             end
             """
    end

    test "don't apply it if already patched" do
      code = """
      defmodule MyAppWeb do
        def view do
          quote do
            use Phoenix.View,
              root: "lib/my_app_web/templates",
              namespace: MyAppWeb

            # Include shared imports and aliases for views
            unquote(view_helpers())
            import Surface
            use Surface.View, root: "lib/my_app_web/templates"
          end
        end
      end
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(code, add_layout_config_to_view_macro("lib/my_app_web", MyAppWeb))
    end
  end
end
