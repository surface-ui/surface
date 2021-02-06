defmodule Surface.Components.LinkTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.Link

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        <Link to="/users/1" click="my_click"/>
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

  test "creates a link without label" do
    html =
      render_surface do
        ~H"""
        <Link to="/users/1" />
        """
      end

    assert html =~ """
           <a href="/users/1"></a>
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
    html =
      render_surface do
        ~H"""
        <Link
          label="user"
          to="/users/1"
          class="link"
          opts={{ method: :delete, data: [confirm: "Really?"], csrf_token: "token" }}
        />
        """
      end

    assert html =~ """
           <a \
           data-confirm="Really?" \
           data-csrf="token" \
           data-method="delete" \
           data-to="/users/1" \
           rel="nofollow" \
           class="link" \
           href="/users/1">user</a>
           """
  end

  test "click event with parent live view as target" do
    html =
      render_surface do
        ~H"""
        <Link to="/users/1" click="my_click" />
        """
      end

    assert html =~ """
           <a phx-click="my_click" href="/users/1"></a>
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
             <a phx-click="my_click" phx-target=".+" href="/users/1"></a>
           </div>
           """
  end
end
