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

  describe "__mix_recompile__?" do
    @new_file_path "test/support/view_test/templates/foo/recompilation_test.sface"
    test "returns true when list of templates from the view changes" do
      on_exit(fn -> File.rm!(@new_file_path) end)

      refute MyAppWeb.FooView.SurfaceRecompilationHelper.__mix_recompile__?()
      File.touch!(@new_file_path)
      assert MyAppWeb.FooView.SurfaceRecompilationHelper.__mix_recompile__?()
    end
  end

  describe "hash/2" do
    test "returns hash of all template paths for the given view" do
      assert is_binary(Surface.View.hash(FooView, "test/support/view_test/templates"))
    end
  end
end
