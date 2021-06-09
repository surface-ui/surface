defmodule Surface.Catalogue.CatalogueTest do
  use ExUnit.Case

  alias Surface.Catalogue.FakeExample
  alias Surface.Catalogue.FakePlayground
  alias Surface.Catalogue.FakeExampleWithUserConfig

  describe "get_config/1" do
    test "get default configuration if none is provided" do
      config = Surface.Catalogue.get_config(FakeExample)

      assert config[:head_css] =~ "/css/app.css"
      assert config[:head_js] =~ "/js/app.js"
    end

    test "calalogue config overrides default config" do
      config = Surface.Catalogue.get_config(FakePlayground)

      assert config[:head_css] =~ "Catalogue's fake head css"
      assert config[:head_js] =~ "Catalogue's fake head js"
    end

    test "user config overrides default and catalogue configs" do
      config = Surface.Catalogue.get_config(FakeExampleWithUserConfig)

      assert config[:head_css] =~ "User's fake css"
      assert config[:head_js] =~ "User's fake js"
    end
  end
end
