defmodule Surface.Components.LiveFileInput do
  @moduledoc """
  Wrapper around Phoenix LiveView's built-in
  `live_file_input/2` function.

  The parent LiveView, or LiveComponent must `allow_uploads` during mount:

  ```elixir
    def mount(socket) do
      socket = allow_upload(socket, :test, accept: ~w(.json), max_entries: 1)
      {:ok, socket}
    end
  ```

  See Phoenix.LiveView [Uploads documentation](https://hexdocs.pm/phoenix_live_view/uploads.html#content)
  """
  use Surface.Component
  @doc "Upload specified via `allow_upload`"
  prop upload, :any, required: true
  @doc "Classes to be used on the generated `input` element"
  prop class, :css_class, default: []
  @doc "Other DOM attributes to be passed to the `input` element"
  prop opts, :keyword, default: []

  def render(assigns) do
    ~H"{{ live_file_input(@upload, [class: @class] ++ @opts) }}"
  end
end
