defmodule Surface.Components.Form.SearchInputTest do
  use ExUnit.Case, async: true

  import ComponentTestHelper
  alias Surface.Components.Form.SearchInput, warn: false

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

  test "setting the class" do
    code = """
    <SearchInput form="song" field="title" class="input" />
    """

    assert render_live(code) =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    code = """
    <SearchInput form="song" field="title" class="input primary" />
    """

    assert render_live(code) =~ ~r/class="input primary"/
  end

  test "passing other options" do
    code = """
    <SearchInput form="song" field="title" opts={{ id: "myid", autofocus: "autofocus" }} />
    """

    assert render_live(code) =~ """
           <input autofocus="autofocus" id="myid" name="song[title]" type="search"/>
           """
  end

  test "blur event with parent live view as target" do
    code = """
    <SearchInput form="user" field="color" value="mytitle" blur="my_blur" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="search" value="mytitle"/>
           """
  end

  test "focus event with parent live view as target" do
    code = """
    <SearchInput form="user" field="color" value="mytitle" focus="my_focus" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="search" value="mytitle"/>
           """
  end

  test "capture click event with parent live view as target" do
    code = """
    <SearchInput form="user" field="color" value="mytitle" capture_click="my_click" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="search" value="mytitle"/>
           """
  end

  test "keydown event with parent live view as target" do
    code = """
    <SearchInput form="user" field="color" value="mytitle" keydown="my_keydown" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="search" value="mytitle"/>
           """
  end

  test "keyup event with parent live view as target" do
    code = """
    <SearchInput form="user" field="color" value="mytitle" keyup="my_keyup" />
    """

    assert render_live(code) =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="search" value="mytitle"/>
           """
  end
end

defmodule Surface.Components.Form.SearchInputConfigTest do
  use ExUnit.Case

  alias Surface.Components.Form.SearchInput, warn: false
  import ComponentTestHelper

  test ":default_class config" do
    using_config SearchInput, default_class: "default_class" do
      code = """
      <SearchInput/>
      """

      assert render_live(code) =~ ~r/class="default_class"/
    end
  end
end
