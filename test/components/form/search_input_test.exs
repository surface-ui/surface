defmodule Surface.Components.Form.SearchInputTest do
  use ExUnit.Case

  alias Surface.Components.Form.SearchInput, warn: false

  import ComponentTestHelper

  describe "Without LiveView" do
    test "empty input" do
      code = """
      <SearchInput form="song" field="title" />
      """

      assert render_live(code) =~ """
             <input id="song_title" name="song[title]" type="search"/>
             """
    end

    test "setting the value" do
      code = """
      <SearchInput form="song" field="title" value="mytitle" />
      """

      assert render_live(code) =~ """
             <input id="song_title" name="song[title]" type="search" value="mytitle"/>
             """
    end

    test "passing other options" do
      code = """
      <SearchInput form="song" field="title" opts={{ id: "myid", autofocus: "autofocus" }} />
      """

      assert render_live(code) =~ """
             <input autofocus="autofocus" id="myid" name="song[title]" type="search"/>
             """
    end
  end
end
