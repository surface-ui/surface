defmodule Surface.Catalogue.CatalogueTest do
  use ExUnit.Case

  alias Surface.Catalogue.FakeLiveExample
  alias Surface.Catalogue.FakePlayground
  alias Surface.Catalogue.FakeLiveExampleWithUserConfig

  setup do
    Application.delete_env(:surface_catalogue, :assets_config)
    :ok
  end

  describe "get_config/1" do
    test "get default configuration if none is provided" do
      config = Surface.Catalogue.get_config(FakeLiveExample)

      assert config[:head_css] =~ "/assets/app.css"
      assert config[:head_js] =~ "/assets/app.js"
    end

    test ":surface_catalogue config overrides default config" do
      Application.put_env(:surface_catalogue, :assets_config,
        head_css: "Configs's fake head css",
        head_js: "Configs's fake head js"
      )

      config = Surface.Catalogue.get_config(FakeLiveExample)

      assert config[:head_css] =~ "Configs's fake head css"
      assert config[:head_js] =~ "Configs's fake head js"
    end

    test "calalogue config overrides default config" do
      config = Surface.Catalogue.get_config(FakePlayground)

      assert config[:head_css] =~ "Catalogue's fake head css"
      assert config[:head_js] =~ "Catalogue's fake head js"
    end

    test "user config overrides default and catalogue configs" do
      config = Surface.Catalogue.get_config(FakeLiveExampleWithUserConfig)

      assert config[:head_css] =~ "User's fake css"
      assert config[:head_js] =~ "User's fake js"
    end
  end
end
