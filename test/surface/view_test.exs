defmodule MyAppWeb.FooView do
  use Phoenix.Template, root: "test/support/view_test/templates"
  use Surface.View, root: "test/support/view_test/templates"
end

defmodule MyAppWeb.Nested.FooView do
  use Phoenix.Template, root: "test/support/view_test/templates"
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

    test "don't process component-scoped CSS for <style> in layouts" do
      result =
        MyAppWeb.FooView.render("with_style.html", %{})
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      assert result == """
             <style>
               .a {padding: 1px}
             </style>
             <div class="a">Hello!</div>
             """
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

      assert MyAppWeb.FooView.__mix_recompile__?() == false
      File.touch!(@new_file_path)
      assert MyAppWeb.FooView.__mix_recompile__?() == true
    end
  end

  describe "hash/2" do
    test "returns hash of all template paths for the given view" do
      assert is_binary(Surface.View.hash(FooView, "test/support/view_test/templates"))
    end
  end
end
