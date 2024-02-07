defmodule Surface.Components.LivePatchTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.LivePatch

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~F"""
      <div>
        <LivePatch to="/users/1"/>
      </div>
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  describe "Without LiveView" do
    test "creates a link with label" do
      html =
        render_surface do
          ~F"""
          <LivePatch label="user" to="/users/1" />
          """
        end

      assert html == """
             <a href="/users/1" data-phx-link="patch" data-phx-link-state="push">user</a>
             """
    end

    test "creates a link without label" do
      html =
        render_surface do
          ~F"""
          <LivePatch to="/users/1" />
          """
        end

      assert html == """
             <a href="/users/1" data-phx-link="patch" data-phx-link-state="push"></a>
             """
    end

    test "creates a link with default slot" do
      html =
        render_surface do
          ~F"""
          <LivePatch to="/users/1"><span>user</span></LivePatch>
          """
        end

      assert html == """
             <a href="/users/1" data-phx-link="patch" data-phx-link-state="push"><span>user</span></a>
             """
    end

    test "setting the class" do
      html =
        render_surface do
          ~F"""
          <LivePatch label="user" to="/users/1" class="link" />
          """
        end

      assert html == """
             <a href="/users/1" class="link" data-phx-link="patch" data-phx-link-state="push">user</a>
             """
    end

    test "setting multiple classes" do
      html =
        render_surface do
          ~F"""
          <LivePatch label="user" to="/users/1" class="link primary" />
          """
        end

      assert html == """
             <a href="/users/1" class="link primary" data-phx-link="patch" data-phx-link-state="push">user</a>
             """
    end

    test "passing other options" do
      html =
        render_surface do
          ~F"""
          <LivePatch
            label="user"
            to="/users/1"
            class="link"
            opts={method: :delete, "data-confirm": "Really?", "csrf-token": "token"}
          />
          """
        end

      actual = """
      <a href="/users/1" class="link" method="delete" data-confirm="Really?" data-phx-link="patch" data-phx-link-state="push" csrf-token="token">user</a>
      """

      assert attr_map(html) == attr_map(actual)
    end
  end

  def attr_map(html) do
    [{_, attrs, _}] = Floki.parse_fragment!(html)

    Map.new(attrs)
  end
end
