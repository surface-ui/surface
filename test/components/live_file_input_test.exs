defmodule Surface.Components.LiveFileInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.LiveFileInput

  defmodule LiveComponentWithLiveFileInput do
    use Surface.LiveComponent

    data uploads, :map

    def mount(socket) do
      # the second param passed to allow_upload becomes the value of the inputs html `name` attribute
      socket = allow_upload(socket, :avatar, accept: ~w(.json), max_entries: 1)
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
        <LiveFileInput id="test_id" upload={{ @uploads.avatar }} class={{ "test_class", disabled_test: true }} opts={{"data-test": "test-data", name: "a name?"}} />
      """
    end

    def handle_event(_, _, socket) do
      {:noreply, socket}
    end
  end

  test "correctly renders live_file_input/2" do
    html =
      render_surface do
        ~H"""
        <LiveComponentWithLiveFileInput id="test"/>
        """
      end

    assert html =~ "phx-hook=\"Phoenix.LiveFileUpload\""
    assert html =~ "accept=\".json\""
    assert html =~ "class=\"test_class disabled_test\""
    assert html =~ "data-test=\"test-data\""
    assert html =~ "name=\"avatar\""
    assert html =~ "id=\"test_id\""
  end
end
