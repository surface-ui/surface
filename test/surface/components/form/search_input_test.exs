defmodule Surface.Components.Form.SearchInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Form.SearchInput

  test "empty input" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <SearchInput form="song" field={:title} />
        """
      end

    assert html =~ """
           <input id="song_title" name="song[title]" type="search">
           """
  end

  test "setting the value" do
    html =
      render_surface do
        ~F"""
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
        ~F"""
        <SearchInput form="song" field="title" class="input" />
        """
      end

    assert html =~ ~r/class="input"/
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <SearchInput form="song" field="title" class="input primary" />
        """
      end

    assert html =~ ~r/class="input primary"/
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <SearchInput form="song" field="title" opts={autofocus: "autofocus"} />
        """
      end

    assert html =~ """
           <input autofocus="autofocus" id="song_title" name="song[title]" type="search">
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <SearchInput form="user" field="color" value="mytitle" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "setting id and name through props" do
    html =
      render_surface do
        ~F"""
        <SearchInput form="user" field="title" id="mytitle" name="mytitle" />
        """
      end

    assert html =~ """
           <input id="mytitle" name="mytitle" type="search">
           """
  end

  test "setting the phx-value-* values" do
    html =
      render_surface do
        ~F"""
        <SearchInput form="user" field="title" values={a: "one", b: :two, c: 3} />
        """
      end

    assert html =~ """
           <input id="user_title" name="user[title]" phx-value-a="one" phx-value-b="two" phx-value-c="3" type="search">
           """
  end
end

defmodule Surface.Components.Form.SearchInputConfigTest do
  use Surface.ConnCase

  alias Surface.Components.Form.Input
  alias Surface.Components.Form.SearchInput

  test ":default_class config" do
    using_config SearchInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <SearchInput/>
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end

  test "component inherits :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      html =
        render_surface do
          ~F"""
          <SearchInput/>
          """
        end

      assert html =~ ~r/class="inherited_default_class"/
    end
  end

  test ":default_class config overrides inherited :default_class from Form.Input" do
    using_config Input, default_class: "inherited_default_class" do
      using_config SearchInput, default_class: "default_class" do
        html =
          render_surface do
            ~F"""
            <SearchInput/>
            """
          end

        assert html =~ ~r/class="default_class"/
      end
    end
  end
end
