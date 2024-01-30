ExUnit.start()
ExUnit.configure(exclude: [integration: true])

defmodule Router do
  use Phoenix.Router
end

defmodule Endpoint do
  use Phoenix.Endpoint, otp_app: :surface
  plug(Router)
end

defmodule FlokiHelpers do
  import Floki

  def inner_text(html) do
    html |> text() |> String.trim()
  end

  def js_attribute(html, selector, attribute_name) do
    html
    |> attribute(selector, attribute_name)
    |> decode_js()
  end

  def js_attribute(html, attribute_name) do
    html
    |> attribute(attribute_name)
    |> decode_js()
  end

  defp decode_js([]) do
    nil
  end

  defp decode_js([value]) do
    value
    |> Jason.decode!()
  end
end

Application.put_env(:surface, Endpoint,
  secret_key_base: "J4lTFt000ENUVhu3dbIB2P2vRVl2nDBH6FLefnPUImL8mHYNX8Kln/N9J0HH19Mq",
  live_view: [
    signing_salt: "LfCCMxfkGME8S8P8XU3Z6/7+ZlD9611u"
  ]
)

Endpoint.start_link()
