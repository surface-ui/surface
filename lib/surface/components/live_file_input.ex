defmodule Surface.Components.LiveFileInput do
  @moduledoc """
  Wrapper around Phoenix LiveView's built-in
  `live_file_input/2` function.

  The parent LiveView, or LiveComponent must `allow_uploads` during mount:

  ```elixir
    def mount(socket) do
      socket = allow_upload(socket, :avatar, accept: ~w(.json), max_entries: 1)
      {:ok, socket}
    end
  ```

  See Phoenix.LiveView [Uploads documentation](https://hexdocs.pm/phoenix_live_view/uploads.html#content)
  """

  use Surface.Component
  import Surface.Components.Form.Utils, only: [props_to_attr_opts: 2, events_to_opts: 1]

  @doc "Upload specified via `allow_upload`"
  prop upload, :struct, required: true

  @doc "The CSS class for the generated `<input>` element"
  prop class, :css_class

  @doc "Keyword list with options to be passed down to `live_file_input/2`"
  prop opts, :keyword, default: []

  @doc "Triggered when the component loses focus"
  prop blur, :event

  @doc "Triggered when the component receives focus"
  prop focus, :event

  @doc "Triggered when the component receives click"
  prop capture_click, :event

  @doc "Triggered when a button on the keyboard is pressed"
  prop keydown, :event

  @doc "Triggered when a button on the keyboard is released"
  prop keyup, :event

  def render(assigns) do
    attr_opts = props_to_attr_opts(assigns, class: get_config(:default_class))
    event_opts = events_to_opts(assigns)

    ~H"{{ live_file_input(@upload, attr_opts ++ @opts ++ event_opts) }}"
  end
end
