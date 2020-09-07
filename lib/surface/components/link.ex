defmodule Surface.Components.Link do
  @moduledoc """
  Defines a hyperlink.

  Provides a wrapper for Phoenix.HTML.Link's `link/2` function.

  All options passed via `opts` will be sent to `link/2`, `label` and `class` can
  be set directly and will override anything in `opts`.

  ## Examples
  ```
  <Link
    label="user"
    to="/users/1"
    class="is-danger"
    opts={{ method: :delete, data: [confirm: "Really?"] }}
  />

  <Link
    to="/users/1"
    class="is-link"
  >
    <span>user</span>
  </Link>
  ```
  """

  use Surface.Component

  import Phoenix.HTML.Link, only: [link: 2]

  @doc "Place to link to"
  property to, :string, required: true

  @doc "Class or classes to apply to the link"
  property class, :css_class

  @doc "Keyword with options to be passed down to `link/2`"
  property opts, :keyword, default: []

  @doc """
  The label for the generated `<a>` alement, if no content (default slot) is
  provided.
  """
  property label, :string

  @doc "Triggered on click"
  property click, :event

  @doc """
  The content of the generated `<a>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot default

  def render(assigns) do
    children = ~H"<slot>{{ @label }}</slot>"

    ~H"""
    {{ link [to: @to] ++ prop_to_opts(__MODULE__, :class, @class) ++ @opts ++ event_to_opts(@click, :phx_click), do: children }}
    """
  end
end
