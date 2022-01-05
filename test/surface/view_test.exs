defmodule Surface.ViewTest do
  use ExUnit.Case, async: true

  defmodule FooView do
    use Phoenix.View, root: "test/support/view_test/templates"
    use Surface.View, root: "test/support/view_test/templates"
  end

  test "generates render/2 function for sface files found on templates folder" do
    result =
      FooView.render("index.html", %{name: "world"})
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    assert result == "Hello world!\n"
  end
end
