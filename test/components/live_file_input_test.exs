defmodule Surface.Components.LiveFileInputTest do
  use Surface.ConnCase, async: true

  alias Surface.Components.LiveFileInput

  defmodule LiveComponentWithLiveFileInput do
    use Surface.LiveComponent

    data uploads, :map

    def mount(socket) do
      socket = allow_upload(socket, :test, accept: ~w(.json), max_entries: 1)
      {:ok, socket}
    end

    def render(assigns) do
      ~H"""
        <LiveFileInput upload={{@uploads.test}}/>
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
  end
end
