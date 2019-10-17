ExUnit.start()

defmodule ComponentTestHelper do
  def render_surface(code) do
    code
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> String.replace(~r/\n+/, "\n")
  end
end
