defmodule Surface.Components.LivePatchTest do
  use ExUnit.Case, async: true

  alias Surface.Components.LivePatch, warn: false

  import ComponentTestHelper

  defmodule ComponentWithLink do
    use Surface.LiveComponent

    def render(assigns) do
      ~H"""
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
      code = """
      <LivePatch label="user" to="/users/1" />
      """

      assert render_live(code) =~ actual_content("user", to: "/users/1")
    end

    test "creates a link without label" do
      code = """
      <LivePatch to="/users/1" />
      """

      assert render_live(code) =~ actual_content(to: "/users/1")
    end

    test "creates a link with default slot" do
      code = """
      <LivePatch to="/users/1"><span>user</span></LivePatch>
      """

      assert render_live(code) =~ actual_content({:safe, "<span>user</span>"}, to: "/users/1")
    end

    test "setting the class" do
      code = """
      <LivePatch label="user" to="/users/1" class="link" />
      """

      assert render_live(code) =~
               actual_content("user", to: "/users/1", class: "link")
    end

    test "setting multiple classes" do
      code = """
      <LivePatch label="user" to="/users/1" class="link primary" />
      """

      assert render_live(code) =~
               actual_content("user", to: "/users/1", class: "link primary")
    end

    test "passing other options" do
      code = """
      <LivePatch label="user" to="/users/1" class="link" opts={{ method: :delete, "data-confirm": "Really?", "csrf-token": "token" }} />
      """

      rendered = render_live(code)

      actual =
        actual_content("user",
          to: "/users/1",
          class: "link",
          method: :delete,
          data: [confirm: "Really?"],
          csrf_token: "token"
        )

      assert attr_map(rendered) == attr_map(actual)
    end
  end

  def attr_map(html) do
    [{_, attrs, _}] = Floki.parse_fragment!(html)

    Map.new(attrs)
  end

  defp actual_content(text, opts) do
    text
    |> Phoenix.LiveView.Helpers.live_patch(opts)
    |> Phoenix.HTML.safe_to_string()
  end

  defp actual_content(opts) do
    actual_content("", opts)
  end
end
