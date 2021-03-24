defmodule Surface.Components.LiveFileInputTest do
  use Surface.ConnCase, async: true

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
      ~H"""
        <LiveFileInput id="test_id" upload={{ @uploads.avatar }} class={{ "test_class", disabled_test: true  }} opts={{ "data-test": "test-data", name: "a name?" }} />
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
      ~H"""
        <LiveFileInput id="test_id" upload={{ @uploads.avatar }} />
      """
    end
  end

  defmodule LiveFileInputWithoutId do
    use Surface.LiveComponent

    data uploads, :map

    def mount(socket) do
      # the second param passed to allow_upload becomes the value of the inputs html `name` attribute
      socket = allow_upload(socket, :avatar, accept: ~w(.json), max_entries: 1)
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
        <LiveFileInput upload={{ @uploads.avatar }} />
      """
    end
  end

  test "correctly renders live_file_input/2 with `class` and `opts`" do
    html =
      render_surface do
        ~H"""
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
    assert html =~ "id=\"test_id\""
  end

  test "correctly renders live_file_input/2 without `class`" do
    html =
      render_surface do
        ~H"""
        <LiveFileInputWithoutProps id="test" />
        """
      end

    assert !(html =~ "class=\"\"")
    assert html =~ "phx-hook=\"Phoenix.LiveFileUpload\""
    assert html =~ "name=\"avatar\""
  end

  test "correctly renders live_file_input/2 without passing through `id`" do
    html =
      render_surface do
        ~H"""
        <LiveFileInputWithoutId id="test" />
        """
      end

    assert html =~ "phx-hook=\"Phoenix.LiveFileUpload\""
    assert html =~ "id=\"phx-"
  end
end
