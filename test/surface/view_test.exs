defmodule MyAppWeb.FooView do
  use Phoenix.View, root: "test/support/view_test/templates"
  use Surface.View, root: "test/support/view_test/templates"
end

defmodule MyAppWeb.Nested.FooView do
  use Phoenix.View, root: "test/support/view_test/templates"
  use Surface.View, root: "test/support/view_test/templates"
end

defmodule Surface.ViewTest do
  use ExUnit.Case, async: true

  describe "render/2" do
    test "generates render/2 for sface files found on the templates folder" do
      result =
        MyAppWeb.FooView.render("index.html", %{name: "world"})
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert result == "Hello world!\n"
    end

    test "supports nested views" do
      result =
        MyAppWeb.Nested.FooView.render("index.html", %{name: "world"})
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert result == "Nested hello world!\n"
    end
  end
end
