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

  describe "__mix_recompile?__" do
    @new_file_path "test/support/view_test/templates/foo/new_file.sface"
    test "returns true when list of templates from the view changes" do
      on_exit(fn -> File.rm!(@new_file_path) end)

      refute FooView.SurfaceRecompilationHelper.__mix_recompile__?()
      File.touch!(@new_file_path)
      assert FooView.SurfaceRecompilationHelper.__mix_recompile__?()
    end
  end

  describe "hash/2" do
    test "returns hash of all template paths for the given view" do
      assert is_binary(Surface.View.hash(FooView, "test/support/view_test/templates"))
    end
  end
end
