defmodule Surface.Components.Utils do
  @moduledoc false
  import Surface, only: [event_to_opts: 2]

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

  def skip_csrf(opts) do
    Keyword.delete(opts, :csrf_token)
  end

  def opts_to_attrs(opts) do
    for {key, value} <- opts do
      case key do
        :values -> values_to_attrs(value)
        _ -> {key, value}
      end
    end
    |> List.flatten()
  end

  def opts_to_phx_opts(opts) do
    for {key, value} <- opts do
      case key do
        :trigger_action -> {:phx_trigger_action, value}
        _ -> {key, value}
      end
    end
  end

  defp values_to_attrs(values) when is_list(values) do
    for {key, value} <- values do
      {:"phx-value-#{key}", value}
    end
  end

  def events_to_opts(assigns) do
    [
      event_to_opts(assigns.capture_click, :phx_capture_click),
      event_to_opts(assigns.click, :phx_click),
      event_to_opts(assigns.window_focus, :phx_window_focus),
      event_to_opts(assigns.window_blur, :phx_window_blur),
      event_to_opts(assigns.focus, :phx_focus),
      event_to_opts(assigns.blur, :phx_blur),
      event_to_opts(assigns.window_keyup, :phx_window_keyup),
      event_to_opts(assigns.window_keydown, :phx_window_keydown),
      event_to_opts(assigns.keyup, :phx_keyup),
      event_to_opts(assigns.keydown, :phx_keydown),
      values_to_opts(assigns.values)
    ]
    |> List.flatten()
  end

  def events_to_attrs(assigns) do
    assigns
    |> events_to_opts()
    |> opts_to_attrs()
  end

  defp values_to_opts([]) do
    []
  end

  defp values_to_opts(values) when is_list(values) do
    {:values, values}
  end

  defp values_to_opts(_values) do
    []
  end
end
