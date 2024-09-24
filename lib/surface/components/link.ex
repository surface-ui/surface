defmodule Surface.Components.Link do
  @moduledoc """
  > #### Deprecation warning {: .warning}
  >
  > This component has been deprecated in favor of liveview's built-in `<.link>`
  > and will be removed in `v0.13`. See https://hexdocs.pm/phoenix_live_view/live-navigation.html for
  > more info and usage.

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

  @valid_uri_schemes [
    "http:",
    "https:",
    "ftp:",
    "ftps:",
    "mailto:",
    "news:",
    "irc:",
    "gopher:",
    "nntp:",
    "feed:",
    "telnet:",
    "mms:",
    "rtsp:",
    "svn:",
    "tel:",
    "fax:",
    "xmpp:"
  ]

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

  @doc "Triggered when the component receives click"
  prop click, :event

  @doc "Triggered when a click event happens outside of the element"
  prop click_away, :event

  # TODO: Remove this when LV min is >= v0.20.15
  @doc "Triggered when the component captures click"
  prop capture_click, :event

  @doc "Triggered when the component loses focus"
  prop blur, :event

  @doc "Triggered when the component receives focus"
  prop focus, :event

  @doc "Triggered when the page loses focus"
  prop window_blur, :event

  @doc "Triggered when the page receives focus"
  prop window_focus, :event

  @doc "Triggered when a key on the keyboard is pressed"
  prop keydown, :event

  @doc "Triggered when a key on the keyboard is released"
  prop keyup, :event

  @doc "Triggered when a key on the keyboard is pressed (window-level)"
  prop window_keydown, :event

  @doc "Triggered when a key on the keyboard is released (window-level)"
  prop window_keyup, :event

  @doc "List values that will be sent as part of the payload triggered by an event"
  prop values, :keyword, default: []

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

  def csrf_data(to, opts) do
    case Keyword.pop(opts, :csrf_token, true) do
      {csrf, opts} when is_binary(csrf) ->
        {[csrf: csrf], opts}

      {true, opts} ->
        {[csrf: csrf_token(to)], opts}

      {false, opts} ->
        {[], opts}
    end
  end

  defp csrf_token(to) do
    {mod, fun, args} = Application.fetch_env!(:surface, :csrf_token_reader)
    apply(mod, fun, [to | args])
  end

  def valid_destination!(%URI{} = uri, context) do
    valid_destination!(URI.to_string(uri), context)
  end

  def valid_destination!({:safe, to}, context) do
    {:safe, valid_string_destination!(IO.iodata_to_binary(to), context)}
  end

  def valid_destination!({other, to}, _context) when is_atom(other) do
    [Atom.to_string(other), ?:, to]
  end

  def valid_destination!(to, context) do
    valid_string_destination!(IO.iodata_to_binary(to), context)
  end

  for scheme <- @valid_uri_schemes do
    def valid_string_destination!(unquote(scheme) <> _ = string, _context), do: string
  end

  def valid_string_destination!(to, context) do
    if not match?("/" <> _, to) and String.contains?(to, ":") do
      raise ArgumentError, """
      unsupported scheme given to #{context}. In case you want to link to an
      unknown or unsafe scheme, such as javascript, use a tuple: {:javascript, rest}
      """
    else
      to
    end
  end

  def events_to_opts(assigns) do
    [
      event_to_opts(assigns.capture_click, :"phx-capture-click"),
      event_to_opts(assigns.click, :"phx-click"),
      event_to_opts(assigns.click_away, :"phx-click-away"),
      event_to_opts(assigns.window_focus, :"phx-window-focus"),
      event_to_opts(assigns.window_blur, :"phx-window-blur"),
      event_to_opts(assigns.focus, :"phx-focus"),
      event_to_opts(assigns.blur, :"phx-blur"),
      event_to_opts(assigns.window_keyup, :"phx-window-keyup"),
      event_to_opts(assigns.window_keydown, :"phx-window-keydown"),
      event_to_opts(assigns.keyup, :"phx-keyup"),
      event_to_opts(assigns.keydown, :"phx-keydown"),
      values_to_opts(assigns.values)
    ]
    |> List.flatten()
  end

  defp values_to_opts([]) do
    []
  end

  defp values_to_opts(values) when is_list(values) do
    values_to_attrs(values)
  end

  defp values_to_opts(_values) do
    []
  end

  defp values_to_attrs(values) when is_list(values) do
    for {key, value} <- values do
      {:"phx-value-#{key}", value}
    end
  end

  def skip_csrf(opts) do
    Keyword.delete(opts, :csrf_token)
  end
end
