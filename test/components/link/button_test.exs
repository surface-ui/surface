defmodule Surface.Components.Link.ButtonTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Link.Button

  defmodule ComponentWithButton do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        <Button label="user" to="/users/1" capture_click="my_click" />
      </div>
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  test "creates a button with label" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <Button label="user" to="/users/1" />
        """
      end

    assert html =~ """
           <button data-csrf="#{csrf_token}" data-method="post" data-to="/users/1">user</button>
           """
  end

  test "creates a button with default slot" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <Button to="/users/1"><span>user</span></Button>
        """
      end

    assert html =~ """
           <button data-csrf="#{csrf_token}" data-method="post" data-to="/users/1"><span>user</span></button>
           """
  end

  test "setting the class" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <Button label="user" to="/users/1" class="link" />
        """
      end

    assert html =~ """
           <button data-csrf="#{csrf_token}" data-method="post" data-to="/users/1" class="link">user</button>
           """
  end

  test "setting multiple classes" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <Button label="user" to="/users/1" class="link primary" />
        """
      end

    assert html =~ """
           <button data-csrf="#{csrf_token}" data-method="post" data-to="/users/1" class="link primary">user</button>
           """
  end

  test "passing other options" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <Button label="user" to="/users/1" method={:delete} opts={data: [confirm: "Really?"]} />
        """
      end

    assert html =~ """
           <button data-confirm="Really?" data-csrf="#{csrf_token}" data-method="delete" data-to="/users/1">user</button>
           """
  end

  test "events with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Button label="user" to="/users/1" click="my_click" />
        """
      end

    assert html =~ ~s(phx-click="my_click")
  end

  test "click event with @myself as target" do
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    html =
      render_surface do
        ~H"""
        <ComponentWithButton id="comp"/>
        """
      end

    assert html =~ ~r"""
           <div>
             <button data-csrf="#{csrf_token}" data-method="post" data-to="/users/1" phx-capture-click="my_click" phx-target=".+">user</button>
           </div>
           """
  end

  describe "is compatible with phoenix button/2" do
    test "button with post (default)" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~H"""
          <Button label="hello" to="/world" />
          """
        end

      assert html =~
               ~s[<button data-csrf="#{csrf_token}" data-method="post" data-to="/world">hello</button>]
    end

    test "button with post without csrf_token" do
      html =
        render_surface do
          ~H"""
          <Button label="hello" to="/world"  opts={csrf_token: false} />
          """
        end

      assert html =~
               ~s[<button data-method="post" data-to="/world">hello</button>]
    end

    test "button with get does not generate CSRF" do
      html =
        render_surface do
          ~H"""
          <Button label="hello" to="/world" method={:get} />
          """
        end

      assert html =~
               ~s[<button data-method="get" data-to="/world">hello</button>]
    end

    test "button with do" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~H"""
          <Button to="/world" class="small">
            {Phoenix.HTML.raw("<span>Hi</span>")}
          </Button>
          """
        end

      assert html ==
               """
               <button data-csrf="#{csrf_token}" data-method="post" data-to="/world" class="small">
                 <span>Hi</span>
               </button>
               """
    end

    test "button with class overrides default" do
      csrf_token = Plug.CSRFProtection.get_csrf_token()

      html =
        render_surface do
          ~H"""
          <Button label="hello" to="/world" class="btn rounded" id="btn" />
          """
        end

      assert html =~
               ~s[<button data-csrf="#{csrf_token}" data-method="post" data-to="/world" id="btn" class="btn rounded">hello</button>]
    end

    test "button with invalid args" do
      msg = """
      unsupported scheme given to <Button />. In case you want to link to an
      unknown or unsafe scheme, such as javascript, use a tuple: {:javascript, rest}
      """

      assert_raise ArgumentError, msg, fn ->
        render_surface do
          ~H"""
          <Button label="foo" to="javascript:alert(1)" method={:get} />
          """
        end
      end
    end
  end
end
