ExUnit.start()

defmodule ComponentTestHelper do
  def render_surface(code) do
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
end

Application.put_env(:surface, Endpoint, [
  secret_key_base: "J4lTFt000ENUVhu3dbIB2P2vRVl2nDBH6FLefnPUImL8mHYNX8Kln/N9J0HH19Mq",
  live_view: [
    signing_salt: "LfCCMxfkGME8S8P8XU3Z6/7+ZlD9611u"
  ]
])

defmodule Router do
  use Phoenix.Router
end

defmodule Endpoint do
  use Phoenix.Endpoint, otp_app: :surface
  plug Router
end
