defmodule Surface.Components.LiveRedirectTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.LiveRedirect

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~F"""
      <div>
        <LiveRedirect to="/users/1"/>
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
        <LiveRedirect label="user" to="/users/1" />
        """
      end

    assert html =~ actual_content("user", to: "/users/1")
  end

  test "creates a link without label" do
    html =
      render_surface do
        ~F"""
        <LiveRedirect to="/users/1" />
        """
      end

    assert html =~ actual_content(to: "/users/1")
  end

  test "creates a link with default slot" do
    html =
      render_surface do
        ~F"""
        <LiveRedirect to="/users/1"><span>user</span></LiveRedirect>
        """
      end

    assert html =~ actual_content({:safe, "<span>user</span>"}, to: "/users/1")
  end

  test "setting the class" do
    html =
      render_surface do
        ~F"""
        <LiveRedirect label="user" to="/users/1" class="link" />
        """
      end

    assert html =~ actual_content("user", to: "/users/1", class: "link")
  end

  test "setting multiple classes" do
    html =
      render_surface do
        ~F"""
        <LiveRedirect label="user" to="/users/1" class="link primary" />
        """
      end

    assert html =~ actual_content("user", to: "/users/1", class: "link primary")
  end

  test "passing other options" do
    html =
      render_surface do
        ~F"""
        <LiveRedirect
          label="user"
          to="/users/1"
          class="link"
          opts={method: :delete, "data-confirm": "Really?", "csrf-token": "token"}
        />
        """
      end

    actual =
      actual_content("user",
        to: "/users/1",
        class: "link",
        method: :delete,
        data: [confirm: "Really?"],
        csrf_token: "token"
      )

    assert attr_map(html) == attr_map(actual)
  end

  def attr_map(html) do
    [{_, attrs, _}] = Floki.parse_fragment!(html)

    Map.new(attrs)
  end

  defp actual_content(text, opts) do
    text
    |> Phoenix.LiveView.Helpers.live_redirect(opts)
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp actual_content(opts) do
    actual_content("", opts)
  end
end
