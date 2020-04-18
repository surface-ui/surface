defmodule Surface.PropertiesTest do
  use ExUnit.Case
  use Phoenix.ConnTest

  import Surface
  import ComponentTestHelper

  defmodule Props do
    use Surface.Component

    property keyword, :keyword
    property map, :map

    def render(assigns) do
      ~H"""
      <span :if={{@keyword}}>{{inspect(@keyword)}}</span>
      <span :if={{@map}}>{{inspect(@map)}}</span>
      """
    end
  end

  describe "keyword" do
    test "passing a keyword list" do
      code = """
      <Props keyword={{ [option1: 1, option2: 2] }}/>
      """

      assert render_live(code) =~ "[option1: 1, option2: 2]"
    end

    test "passing a keyword list without brackets" do
      code = """
      <Props keyword={{ option1: 1, option2: 2 }}/>
      """

      assert render_live(code) =~ "[option1: 1, option2: 2]"
    end
  end

  describe "map" do
    test "passing a map" do
      code = """
      <Props map={{ %{option1: 1, option2: 2} }}/>
      """

      assert render_live(code) =~ "%{option1: 1, option2: 2}"
    end

    test "passing a keyword list" do
      code = """
      <Props map={{ [option1: 1, option2: 2] }}/>
      """

      assert render_live(code) =~ "%{option1: 1, option2: 2}"
    end

    test "accepts a keyword list without brackets" do
      code = """
      <Props map={{ option1: 1, option2: 2 }}/>
      """

      assert render_live(code) =~ "%{option1: 1, option2: 2}"
    end
  end
end
