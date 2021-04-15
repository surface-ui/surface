defmodule Surface.Components.LinkTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Link

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        <Link label="user" to="/users/1" capture_click="my_click" />
      </div>
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  test "creates a link with label" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" />
        """
      end

    assert html =~ """
           <a href="/users/1">user</a>
           """
  end

  test "creates a link with default slot" do
    html =
      render_surface do
        ~H"""
        <Link to="/users/1"><span>user</span></Link>
        """
      end

    assert html =~ """
           <a href="/users/1"><span>user</span></a>
           """
  end

  test "setting the class" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" class="link" />
        """
      end

    assert html =~ """
           <a class="link" href="/users/1">user</a>
           """
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" class="link primary" />
        """
      end

    assert html =~ """
           <a class="link primary" href="/users/1">user</a>
           """
  end

  test "passing other options" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" method={{ :delete }} opts={{ data: [confirm: "Really?"] }} />
        """
      end

    assert html =~ """
           <a data-confirm="Really?" data-csrf="#{csrf_token}" data-method="delete" data-to="/users/1" rel="nofollow" href="/users/1">user</a>
           """
  end

  test "window blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" window_blur="my_blur" />
        """
      end

    assert html =~ """
           <a phx-window-blur="my_blur" href="/users/1">user</a>
           """
  end

  test "window focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" window_focus="my_focus" />
        """
      end

    assert html =~ """
           <a phx-window-focus="my_focus" href="/users/1">user</a>
           """
  end

  test "blur event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" blur="my_blur" />
        """
      end

    assert html =~ """
           <a phx-blur="my_blur" href="/users/1">user</a>
           """
  end

  test "focus event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" focus="my_focus" />
        """
      end

    assert html =~ """
           <a phx-focus="my_focus" href="/users/1">user</a>
           """
  end

  test "capture click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" capture_click="my_click" />
        """
      end

    assert html =~ """
           <a phx-capture-click="my_click" href="/users/1">user</a>
           """
  end

  test "click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" click="my_click" />
        """
      end

    assert html =~ """
           <a phx-click="my_click" href="/users/1">user</a>
           """
  end

  test "window keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" window_keydown="my_keydown" />
        """
      end

    assert html =~ """
           <a phx-window-keydown="my_keydown" href="/users/1">user</a>
           """
  end

  test "window keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" window_keyup="my_keyup" />
        """
      end

    assert html =~ """
           <a phx-window-keyup="my_keyup" href="/users/1">user</a>
           """
  end

  test "keydown event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" keydown="my_keydown" />
        """
      end

    assert html =~ """
           <a phx-keydown="my_keydown" href="/users/1">user</a>
           """
  end

  test "keyup event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link label="user" to="/users/1" keyup="my_keyup" />
        """
      end

    assert html =~ """
           <a phx-keyup="my_keyup" href="/users/1">user</a>
           """
  end

  test "click event with @myself as target" do
    html =
      render_surface do
        ~H"""
        <ComponentWithLink id="comp"/>
        """
      end

    assert html =~ ~r"""
           <div>
             <a phx-capture-click="my_click" phx-target="1" href="/users/1">user</a>
           </div>
           """
  end

  describe "is compatible with phoenix link/2" do
    test "link with post" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~H"""
          <Link label="hello" to="/world" method={{ :post }} />
          """
        end

      assert html =~
               ~s[<a data-csrf="#{csrf_token}" data-method="post" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with %URI{}" do
      url = "https://surface-ui.org/"

      assert render_surface(do: ~H[<Link label="elixir" to={{ url }} />]) ==
               render_surface(do: ~H[<Link label="elixir" to={{ URI.parse(url) }} />])

      path = "/surface"

      assert render_surface(do: ~H[<Link label="elixir" to={{ path }} />]) ==
               render_surface(do: ~H[<Link label="elixir" to={{ URI.parse(path) }} />])
    end

    test "link with put/delete" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~H"""
          <Link label="hello" to="/world" method={{ :put }} />
          """
        end

      assert html =~
               ~s[<a data-csrf="#{csrf_token}" data-method="put" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with put/delete without csrf_token" do
      html =
        render_surface do
          ~H"""
          <Link label="hello" to="/world" method={{ :put }} opts={{ csrf_token: false }} />
          """
        end

      assert html =~
               ~s[<a data-method="put" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with :do contents" do
      html =
        render_surface do
          ~H"""
          <Link to="/hello">
            {{ Phoenix.HTML.Tag.content_tag(:p, "world") }}
          </Link>
          """
        end

      assert html == """
             <a href="/hello">
               <p>world</p>
             </a>
             """
    end

    test "link with scheme" do
      html = render_surface(do: ~H[<Link label="foo" to="/javascript:alert(<1>)" />])
      assert html =~ ~s[<a href="/javascript:alert(&lt;1&gt;)">foo</a>]

      html =
        render_surface(do: ~H[<Link label="foo" to={{ {:safe, "/javascript:alert(<1>)"} }} />])

      assert html =~ ~s[<a href="/javascript:alert(<1>)">foo</a>]

      html = render_surface(do: ~H[<Link label="foo" to={{ {:javascript, "alert(<1>)"} }} />])
      assert html =~ ~s[<a href="javascript:alert(&lt;1&gt;)">foo</a>]

      html = render_surface(do: ~H[<Link label="foo" to={{ {:javascript, 'alert(<1>)'} }} />])
      assert html =~ ~s[<a href="javascript:alert(&lt;1&gt;)">foo</a>]

      html =
        render_surface(do: ~H[<Link label="foo" to={{ {:javascript, {:safe, "alert(<1>)"}} }} />])

      assert html =~ ~s[<a href="javascript:alert(<1>)">foo</a>]

      html =
        render_surface(do: ~H[<Link label="foo" to={{ {:javascript, {:safe, 'alert(<1>)'}} }} />])

      assert html =~ ~s[<a href="javascript:alert(<1>)">foo</a>]
    end

    test "link with invalid args" do
      msg = "<Link /> requires a label prop or contents in the default slot"

      assert_raise ArgumentError, msg, fn ->
        render_surface(do: ~H[<Link to="/hello-world" />])
      end

      assert_raise ArgumentError, ~r"unsupported scheme given to <Link />", fn ->
        render_surface(do: ~H[<Link label="foo" to="javascript:alert(<1>)" />])
      end

      assert_raise ArgumentError, ~r"unsupported scheme given to <Link />", fn ->
        render_surface(do: ~H[<Link label="foo" to={{ {:safe, "javascript:alert(<1>)"} }} />])
      end

      assert_raise ArgumentError, ~r"unsupported scheme given to <Link />", fn ->
        render_surface(do: ~H[<Link label="foo" to={{ {:safe, 'javascript:alert(<1>)'} }} />])
      end
    end
  end
end
