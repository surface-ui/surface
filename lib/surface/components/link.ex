defmodule Surface.Components.Link do
  @moduledoc """
  Generates a link to the given URL.

  Provides similar capabilities to Phoenix's built-in `link/2`
  function.

  Options `label` and `class` can be set directly and will override anything in `opts`.
  All other options are forwarded to the underlying <a> tag.

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

  @doc "The page to link to"
  prop to, :any, required: true

  @doc "The method to use with the link"
  prop method, :atom, default: :get

  @doc "Class or classes to apply to the link"
  prop class, :css_class

  @doc """
  The label for the generated `<a>` element, if no content (default slot) is provided.
  """
  prop label, :string

  @doc "Triggered on click"
  prop click, :event

  @doc """
  Additional attributes to add onto the generated element
  """
  prop opts, :keyword, default: []

  @doc """
  The content of the generated `<a>` element. If no content is provided,
  the value of property `label` is used instead.
  """
  slot default

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

  def update(assigns, socket) do
    unless assigns[:default] || assigns[:label] || Keyword.get(assigns.opts, :label) do
      raise ArgumentError, "<Link /> requires a label prop or contents in the default slot"
    end

    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    opts = props_to_opts(assigns)

    ~H"""
    <a
      class={{ @class }}
      href={{ valid_destination!(@to, "<Link />") }}
      :attrs={{ @opts ++ opts ++ event_to_opts(@click, :phx_click) |> opts_to_attrs(assigns) }}
    ><slot>{{ @label }}</slot></a>
    """
  end

  defp props_to_opts(assigns) do
    props = [:method]

    for prop <- props, {key, value} = prop_value(assigns, prop), value != nil do
      {key, value}
    end
  end

  defp prop_value(assigns, prop) do
    {prop, assigns[prop]}
  end

  defp opts_to_attrs(opts, assigns) do
    for {key, value} <- opts do
      case key do
        :csrf_token -> {:"data-csrf", value}
        :phx_click -> {:"phx-click", value}
        :phx_target -> {:"phx-target", value}
        :method -> method_to_attrs(value, assigns.to, opts)
        :data -> data_to_attrs(value)
        _ -> {key, value}
      end
    end
    |> List.flatten()
  end

  defp method_to_attrs(method, to, opts) do
    case method do
      :get -> []
      _ -> ["data-method": method, "data-to": to, rel: "nofollow"] ++ csrf_data(to, opts)
    end
  end

  defp csrf_data(to, opts) do
    case Keyword.get(opts, :csrf_token, true) do
      csrf when is_binary(csrf) -> ["data-csrf": csrf]
      true -> ["data-csrf": csrf_token(to)]
      false -> []
    end
  end

  defp csrf_token(to) do
    {mod, fun, args} = Application.fetch_env!(:surface, :csrf_token_reader)
    apply(mod, fun, [to | args])
  end

  defp data_to_attrs(data) when is_list(data) do
    for {key, value} <- data do
      {:"data-#{key}", value}
    end
  end

  defp valid_destination!(%URI{} = uri, context) do
    valid_destination!(URI.to_string(uri), context)
  end

  defp valid_destination!({:safe, to}, context) do
    {:safe, valid_string_destination!(IO.iodata_to_binary(to), context)}
  end

  defp valid_destination!({other, to}, _context) when is_atom(other) do
    [Atom.to_string(other), ?:, to]
  end

  defp valid_destination!(to, context) do
    valid_string_destination!(IO.iodata_to_binary(to), context)
  end

  for scheme <- @valid_uri_schemes do
    defp valid_string_destination!(unquote(scheme) <> _ = string, _context), do: string
  end

  defp valid_string_destination!(to, context) do
    if not match?("/" <> _, to) and String.contains?(to, ":") do
      raise ArgumentError, """
      unsupported scheme given to #{context}. In case you want to link to an
      unknown or unsafe scheme, such as javascript, use a tuple: {:javascript, rest}
      """
    else
      to
    end
  end
end
