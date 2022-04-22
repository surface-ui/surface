defmodule Mix.Tasks.Surface.Init.ProjectPatchers.ErrorTagTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Surface.Init.Patcher
  import Mix.Tasks.Surface.Init.ProjectPatchers.ErrorTag

  describe "patch_config_error_tag" do
    test "add `config :surface, :components` with the ErrorTag config" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      {:patched, updated_code} = Patcher.patch_code(code, config_error_tag(MyAppWeb))

      assert updated_code == ~S"""
             import Config

             config :surface, :components, [
               {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
             ]

             # Use Jason for JSON parsing in Phoenix
             config :phoenix, :json_library, Jason

             # Import environment specific config. This must remain at the bottom
             # of this file so it overrides the configuration defined above.
             import_config "#{config_env()}.exs"
             """
    end

    test "append the ErrorTag config, if `config :surface, :components` elready exists" do
      code = ~S"""
      import Config

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      config :surface, :components, [
        {Surface.Components.Markdown, default_class: "content"}
      ]

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      {:patched, updated_code} = Patcher.patch_code(code, config_error_tag(MyAppWeb))

      assert updated_code == ~S"""
             import Config

             # Use Jason for JSON parsing in Phoenix
             config :phoenix, :json_library, Jason

             config :surface, :components, [
               {Surface.Components.Markdown, default_class: "content"},
               {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
             ]

             # Import environment specific config. This must remain at the bottom
             # of this file so it overrides the configuration defined above.
             import_config "#{config_env()}.exs"
             """
    end

    test "don't apply it if already patched" do
      code = ~S"""
      import Config

      config :surface, :components, [
        {Surface.Components.Markdown, default_class: "content"},
        {Surface.Components.Form.ErrorTag, default_translator: {MyAppWeb.ErrorHelpers, :translate_error}}
      ]

      # Use Jason for JSON parsing in Phoenix
      config :phoenix, :json_library, Jason

      # Import environment specific config. This must remain at the bottom
      # of this file so it overrides the configuration defined above.
      import_config "#{config_env()}.exs"
      """

      assert {:already_patched, ^code} = Patcher.patch_code(code, config_error_tag(MyAppWeb))
    end
  end
end
