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
    html = render_surface_component(Link, label: "user", to: "/users/1")

    assert html =~ """
           <a href="/users/1">user</a>
           """
  end

  test "creates a link without label" do
    html = render_surface_component(Link, to: "/users/1")

    assert html =~ """
           <a href="/users/1"></a>
           """
  end

  test "creates a link with default slot" do
    html =
      render_surface_component(Link, to: "/users/1") do
        ~H"""
        <span>user</span>
        """
      end

    assert html =~ """
           <a href="/users/1"><span>user</span>
           </a>
           """
  end

  test "setting the class" do
    html = render_surface_component(Link, label: "user", to: "/users/1", class: ["link"])

    assert html =~ """
           <a class="link" href="/users/1">user</a>
           """
  end

  test "setting multiple classes" do
    html =
      render_surface_component(Link, label: "user", to: "/users/1", class: ["link", "primary"])

    assert html =~ """
           <a class="link primary" href="/users/1">user</a>
           """
  end

  test "passing other options" do
    html =
      render_surface_component(Link,
        label: "user",
        to: "/users/1",
        class: ["link"],
        opts: [method: :delete, data: [confirm: "Really?"], csrf_token: "token"]
      )

    assert html =~ """
           <a class="link" data-confirm="Really?" data-csrf="token" data-method="delete" data-to="/users/1" href="/users/1" rel="nofollow">user</a>
           """
  end

  test "click event with parent live view as target" do
    html =
      render_surface_component(Link,
        to: "/users/1",
        click: %{name: "my_click", target: :live_view}
      )

    assert html =~ """
           <a href="/users/1" phx-click="my_click"></a>
           """
  end

  test "click event with @myself as target" do
    html = render_surface_component(ComponentWithLink, id: "comp")

    assert html =~ ~r"""
           <div>
             <a href="/users/1" phx-click="my_click" phx-target=".+"></a>
           </div>
           """
  end
end
