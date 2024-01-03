defmodule Mix.Tasks.Surface.Init.ProjectPatchers.TailwindTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.Tailwind

  describe "add_sface_patterns_to_tailwind_config_js" do
    test "Add surface files to tailwind.config.js content section" do
      code = """
      const plugin = require("tailwindcss/plugin")

      module.exports = {
        content: [
          "./js/**/*.js",
          "../lib/my_app_web.ex",
          "../lib/my_app_web/**/*.*ex"
        ],
        theme: {
          extend: {},
        },
        plugins: [
          require('@tailwindcss/forms')
        ]
      }
      """

      {:patched, updated_code} = Patcher.patch_code(code, add_sface_patterns_to_tailwind_config_js(:my_app))

      assert updated_code == """
             const plugin = require("tailwindcss/plugin")

             module.exports = {
               content: [
                 "./js/**/*.js",
                 "../lib/my_app_web.ex",
                 "../lib/my_app_web/**/*.*ex",
                 "../lib/my_app_web/**/*.sface",
                 "../priv/catalogue/**/*.{ex,sface}"
               ],
               theme: {
                 extend: {},
               },
               plugins: [
                 require('@tailwindcss/forms')
               ]
             }
             """
    end

    test "don't apply it if already patched" do
      code = """
      module.exports = {
        content: [
          "./js/**/*.js",
          "../lib/my_app_web.ex",
          "../lib/my_app_web/**/*.*ex",
          "../lib/my_app_web/**/*.sface",
          "../priv/catalogue/**/*.{ex,sface}"
        ],
        theme: {
          extend: {},
        },
        plugins: []
      }
      """

      assert {:already_patched, ^code} =
               Patcher.patch_code(code, add_sface_patterns_to_tailwind_config_js(:my_app))
    end
  end
end
