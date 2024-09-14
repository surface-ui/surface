defmodule Surface.Components.LinkTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Link

  defmodule ViewWithLink do
    use Surface.LiveView

    data disabled, :boolean, default: false

    def handle_event("toggle_disable", _, socket) do
      {:noreply, assign(socket, :disabled, !socket.assigns.disabled)}
    end

    def render(assigns) do
      ~F"""
      <Link label="user" to="/users/1" opts={disabled: @disabled} />
      """
    end
  end

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~F"""
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
        ~F"""
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
        ~F"""
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
        ~F"""
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
        ~F"""
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
        ~F"""
        <Link label="user" to="/users/1" method={:delete} opts={data: [confirm: "Really?"]} />
        """
      end

    assert html =~ """
           <a data-confirm="Really?" data-csrf="#{csrf_token}" data-method="delete" data-to="/users/1" rel="nofollow" href="/users/1">user</a>
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~F"""
        <Link label="user" to="/users/1" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "updates when opts change", %{conn: conn} do
    {:ok, view, html} = live_isolated(conn, ViewWithLink)
    refute html =~ ~s(disabled="disabled")
    assert render_click(view, :toggle_disable) =~ ~s(disabled="disabled")
    refute render_click(view, :toggle_disable) =~ ~s(disabled="disabled")
  end

  describe "is compatible with phoenix link/2" do
    test "link with post" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~F"""
          <Link label="hello" to="/world" method={:post} />
          """
        end

      assert html =~
               ~s[<a data-csrf="#{csrf_token}" data-method="post" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with %URI{}" do
      assigns = %{url: "https://surface-ui.org/"}

      assert render_surface(do: ~F[<Link label="elixir" to={@url} />]) ==
               render_surface(do: ~F[<Link label="elixir" to={URI.parse(@url)} />])

      assigns = %{path: "/surface"}

      assert render_surface(do: ~F[<Link label="elixir" to={@path} />]) ==
               render_surface(do: ~F[<Link label="elixir" to={URI.parse(@path)} />])
    end

    test "link with put/delete" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~F"""
          <Link label="hello" to="/world" method={:put} />
          """
        end

      assert html =~
               ~s[<a data-csrf="#{csrf_token}" data-method="put" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with put/delete without csrf_token" do
      html =
        render_surface do
          ~F"""
          <Link label="hello" to="/world" method={:put} opts={csrf_token: false} />
          """
        end

      assert html =~
               ~s[<a data-method="put" data-to="/world" rel="nofollow" href="/world">hello</a>]
    end

    test "link with scheme" do
      html = render_surface(do: ~F[<Link label="foo" to="/javascript:alert(<1>)" />])
      assert html =~ ~s[<a href="/javascript:alert(&lt;1&gt;)">foo</a>]

      html = render_surface(do: ~F[<Link label="foo" to={{:safe, "/javascript:alert(<1>)"}} />])

      assert html =~ ~s[<a href="/javascript:alert(<1>)">foo</a>]

      html = render_surface(do: ~F[<Link label="foo" to={{:javascript, "alert(<1>)"}} />])
      assert html =~ ~s[<a href="javascript:alert(&lt;1&gt;)">foo</a>]

      html = render_surface(do: ~F[<Link label="foo" to={{:javascript, ~c"alert(<1>)"}} />])
      assert html =~ ~s[<a href="javascript:alert(&lt;1&gt;)">foo</a>]

      html = render_surface(do: ~F[<Link label="foo" to={{:javascript, {:safe, "alert(<1>)"}}} />])

      assert html =~ ~s[<a href="javascript:alert(<1>)">foo</a>]

      html = render_surface(do: ~F[<Link label="foo" to={{:javascript, {:safe, ~c"alert(<1>)"}}} />])

      assert html =~ ~s[<a href="javascript:alert(<1>)">foo</a>]
    end

    test "link with invalid arg" do
      msg = "<Link /> requires a label prop or contents in the default slot"

      assert_raise ArgumentError, msg, fn ->
        render_surface(do: ~F[<Link to="/hello-world" />])
      end

      assert_raise ArgumentError, ~r"unsupported scheme given to <Link />", fn ->
        render_surface(do: ~F[<Link label="foo" to="javascript:alert(<1>)" />])
      end

      assert_raise ArgumentError, ~r"unsupported scheme given to <Link />", fn ->
        render_surface(do: ~F[<Link label="foo" to={{:safe, "javascript:alert(<1>)"}} />])
      end

      assert_raise ArgumentError, ~r"unsupported scheme given to <Link />", fn ->
        render_surface(do: ~F[<Link label="foo" to={{:safe, ~c"javascript:alert(<1>)"}} />])
      end
    end
  end
end
