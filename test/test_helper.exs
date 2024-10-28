# Borrowed solution from phoenix_live_view test_helper.exs
# https://github.com/phoenixframework/phoenix_live_view/blob/main/test/test_helper.exs#L4
Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Code.require_file("test/support/debug_annotations.exs")
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

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

defmodule ANSIHelpers do
  @doc """
  Returns a regex fragment that conditionally matches a colored text.

  It should be used in tests to avoid failure when running in enviroments where ANSI
  is disabled, e.g. CI servers.
  """
  def maybe_ansi(text) do
    if IO.ANSI.enabled?() do
      "(\\e\\[\\d+m)?#{text}(\\e\\[0m)"
    else
      text
    end
  end
end

Application.put_env(:surface, Endpoint,
  secret_key_base: "J4lTFt000ENUVhu3dbIB2P2vRVl2nDBH6FLefnPUImL8mHYNX8Kln/N9J0HH19Mq",
  live_view: [
    signing_salt: "LfCCMxfkGME8S8P8XU3Z6/7+ZlD9611u"
  ]
)

Endpoint.start_link()
