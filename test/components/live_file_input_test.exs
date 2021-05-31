defmodule Surface.Components.LiveFileInputTest do
  use Surface.ConnCase

  alias Surface.Components.LiveFileInput
  # requires live_component to test live_upload
  defmodule LiveFileInputWithProps do
    use Surface.LiveComponent

    data uploads, :map

    def mount(socket) do
      # the second param passed to allow_upload becomes the value of the inputs html `name` attribute
      socket = allow_upload(socket, :avatar, accept: ~w(.json), max_entries: 1)
      {:ok, socket}
    end

    def render(assigns) do
      ~F"""
        <LiveFileInput upload={@uploads.avatar} class={"test_class", disabled_test: true} opts={"data-test": "test-data", name: "a name?"} />
      """
    end
  end

  defmodule LiveFileInputWithoutProps do
    use Surface.LiveComponent

    data uploads, :map

    def mount(socket) do
      # the second param passed to allow_upload becomes the value of the inputs html `name` attribute
      socket = allow_upload(socket, :avatar, accept: ~w(.json), max_entries: 1)
      {:ok, socket}
    end

    def render(assigns) do
      ~F"""
        <LiveFileInput upload={@uploads.avatar} />
      """
    end
  end

  test "correctly renders live_file_input/2 with `class` and `opts`" do
    html =
      render_surface do
        ~F"""
        <LiveFileInputWithProps id="test" />
        """
      end

    # expected lv attrs
    assert html =~ "phx-hook=\"Phoenix.LiveFileUpload\""
    assert html =~ "accept=\".json\""
    assert html =~ "name=\"avatar\""
    # expected passed through attrs
    assert html =~ "class=\"test_class disabled_test\""
    assert html =~ "data-test=\"test-data\""
  end

  test "correctly renders live_file_input/2 with `:default_class` config" do
    using_config LiveFileInput, default_class: "default_class" do
      html =
        render_surface do
          ~F"""
          <LiveFileInputWithoutProps id="test" />
          """
        end

      assert html =~ ~r/class="default_class"/
    end
  end
end
