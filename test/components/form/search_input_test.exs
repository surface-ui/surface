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

  test "input with atom field" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="song" field={{ :title }} />
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

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <SearchInput form="user" field="color" value="mytitle"
          capture_click="my_capture_click"
          click="my_click"
          window_focus="my_window_focus"
          window_blur="my_window_blur"
          focus="my_focus"
          blur="my_blur"
          window_keyup="my_window_keyup"
          window_keydown="my_window_keydown"
          keyup="my_keyup"
          keydown="my_keydown"
        />
        """
      end

    assert html =~ ~s(phx-capture-click="my_capture_click")
    assert html =~ ~s(phx-click="my_click")
    assert html =~ ~s(phx-window-focus="my_window_focus")
    assert html =~ ~s(phx-window-blur="my_window_blur")
    assert html =~ ~s(phx-focus="my_focus")
    assert html =~ ~s(phx-blur="my_blur")
    assert html =~ ~s(phx-window-keyup="my_window_keyup")
    assert html =~ ~s(phx-window-keydown="my_window_keydown")
    assert html =~ ~s(phx-keyup="my_keyup")
    assert html =~ ~s(phx-keydown="my_keydown")
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
