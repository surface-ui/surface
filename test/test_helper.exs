ExUnit.start()

defmodule Router do
  use Phoenix.Router
end

defmodule Endpoint do
  use Phoenix.Endpoint, otp_app: :surface
  plug Router
end

Application.put_env(:surface, Endpoint, [
  secret_key_base: "J4lTFt000ENUVhu3dbIB2P2vRVl2nDBH6FLefnPUImL8mHYNX8Kln/N9J0HH19Mq",
  live_view: [
    signing_salt: "LfCCMxfkGME8S8P8XU3Z6/7+ZlD9611u"
  ]
])

Endpoint.start_link()

defmodule ComponentTestHelper do
  require Phoenix.LiveViewTest

  @endpoint Endpoint

  def render_static(code) do
    code
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> String.replace(~r/\n+/, "\n")
  end

  def normalize_html(html) do
    html
    |> String.split("\n")
    |> Enum.map(&String.trim(&1))
    |> Enum.join("")
  end

  defmacro assert_html({op, meta, [lhs, rhs]}) do
    new_lhs = quote do: normalize_html(unquote(lhs))
    new_rhs = quote do: normalize_html(unquote(rhs))

    quote do
      assert unquote({op, meta, [new_lhs, new_rhs]})
    end
  end

  defmacro render_live(code, assigns \\ quote do: %{}) do
    quote do
      render_live(unquote(code), unquote(assigns), unquote(Macro.escape(__CALLER__)))
    end
  end

  def render_live(code, assigns, env) do
    id = :erlang.unique_integer([:positive]) |> to_string()

    view_code =
      "defmodule TestLiveView_#{id} do; " <>
      "  use Surface.LiveView; " <>
      "  def render(assigns) do; " <>
      "    assigns = Map.merge(assigns, #{inspect(assigns)}); " <>
      "    ~H(#{code});" <>
      "  end; " <>
      "end"

    {{:module, module, _, _}, _} = Code.eval_string(view_code, [], %{env | file: "code", line: 0})
    conn = Phoenix.ConnTest.build_conn()
    {:ok, _view, html} = Phoenix.LiveViewTest.live_isolated(conn, module)

    html
    |> String.replace(~r/^<div.+>/U, "")
    |> String.replace(~r/<\/div>$/, "\n")
    |> String.replace(~r/\n+/, "\n")
  end

  def extract_line(message) do
    case Regex.run(~r/.exs:(\d+)/, message) do
      [_, line] ->
        String.to_integer(line)
      _ -> :not_found
    end
  end
end
