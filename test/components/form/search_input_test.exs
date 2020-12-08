defmodule Surface.Components.Form.SearchInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.SearchInput

  test "empty input" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="song" field="title" />
        """
      end

    assert html =~ """
           <input id="song_title" name="song[title]" type="search">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="song" field="title" value="mytitle" />
        """
      end

    assert html =~ """
           <input id="song_title" name="song[title]" type="search" value="mytitle">
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="song" field="title" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="song" field="title" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="song" field="title" opts={{ autofocus: "autofocus" }} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="song_title" name="song[title]" type="search">
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="user" field="color" value="mytitle" blur="my_blur" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-blur="my_blur" type="search" value="mytitle">
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="user" field="color" value="mytitle" focus="my_focus" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-focus="my_focus" type="search" value="mytitle">
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="user" field="color" value="mytitle" capture_click="my_click" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-capture-click="my_click" type="search" value="mytitle">
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="user" field="color" value="mytitle" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keydown="my_keydown" type="search" value="mytitle">
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="user" field="color" value="mytitle" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <input id="user_color" name="user[color]" phx-keyup="my_keyup" type="search" value="mytitle">
           """
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="user" field="title" id="mytitle" name="mytitle" />
        """
      end

    assert html =~ """
           <input id="mytitle" name="mytitle" type="search">
           """
  end
end

defmodule Surface.Components.Form.SearchInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.SearchInput

  test ":default_class config" do
    using_config SearchInput, default_class: "default_class" do
      html =
        render_surface do
          ~H"""
          <SearchInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
