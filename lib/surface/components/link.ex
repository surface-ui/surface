defmodule Surface.Components.Link do
  @moduledoc """
  > #### Deprecation warning {: .warning}
  >
  > This component has been deprecated in favor of liveview's built-in `<.link>`
  > and will be removed in `v0.13`. See https://hexdocs.pm/phoenix_live_view/live-navigation.html for
  > more info usage.

  Generates a link to the given URL.

  Provides similar capabilities to Phoenix's built-in `link/2` function.

  Options `label` and `class` can be set directly and will override anything in `opts`.
  All other options are forwarded to the underlying <a> tag.

  ## Examples
  ```
  <Link
    label="user"
    to="/users/1"
    class="is-danger"
    method={:delete}
    opts={data: [confirm: "Really?"]}
  />

  <Link
    to="/users/1"
    class="is-link"
  >
    <span>user</span>
  </Link>
  ```
  """

  @moduledoc deprecated: "Use liveview's built-in `<.link>` instead"

  use Surface.Component
  use Surface.Components.Events

  import Surface.Components.Utils

  @doc "The page to link to"
  prop to, :any, required: true

  @doc "The method to use with the link"
  prop method, :atom, default: :get

  @doc "Id to apply to the link"
  prop id, :string

  @doc "Class or classes to apply to the link"
  prop class, :css_class

  @doc """
  The label for the generated `<a>` element, if no content (default slot) is provided.
  """
  prop label, :string

  @doc """
  Additional attributes to add onto the generated element
  """
  prop opts, :keyword, default: []

  @doc """
  The content of the generated `<a>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot default

  if Mix.env() != :test do
    @deprecated "Use liveview's built-in `<.link>` instead"
  end

  def render(assigns) do
    unless assigns[:default] || assigns[:label] || Keyword.get(assigns.opts, :label) do
      raise ArgumentError, "<Link /> requires a label prop or contents in the default slot"
    end

    to = valid_destination!(assigns.to, "<Link />")
    events = events_to_opts(assigns)
    opts = link_method(assigns.method, to, assigns.opts)
    assigns = assign(assigns, to: to, opts: events ++ opts)

    ~F"""
    <a id={@id} class={@class} href={@to} :attrs={@opts}><#slot>{@label}</#slot></a>
    """
  end

  defp link_method(method, to, opts) do
    if method == :get do
      skip_csrf(opts)
    else
      {csrf_data, opts} = csrf_data(to, opts)

      data =
        opts
        |> Keyword.get(:data, [])
        |> Keyword.merge(csrf_data)
        |> Keyword.merge(method: method, to: to)

      Keyword.merge(opts, data: data, rel: "nofollow")
    end
  end
end
