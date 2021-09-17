defmodule Mix.Tasks.Compile.SurfaceTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.Compile.Surface

  @hooks_rel_output_dir "tmp/_hooks"
  @hooks_output_dir Path.join(File.cwd!(), @hooks_rel_output_dir)
  @test_components_dir Path.join(File.cwd!(), "test/support/mix/tasks/compile/surface_test")

  @button_src_hooks_file Path.join(@test_components_dir, "fake_button.hooks.js")
  @button_rel_src_hooks_file Path.join("test/support/mix/tasks/compile/surface_test", "fake_button.hooks.js")
  @button_dest_hooks_file Path.join(
                            @hooks_output_dir,
                            "Mix.Tasks.Compile.SurfaceTest.FakeButton.hooks.js"
                          )
  @button_src_hooks_file_content "let FakeButton = {}\nexport { FakeButton }"
  @button_src_hooks_file_content_modified "let FakeButton = { mounted() {} }\nexport { FakeButton }"

  @link_src_hooks_file Path.join(@test_components_dir, "fake_link.hooks.js")
  @link_rel_src_hooks_file Path.join("test/support/mix/tasks/compile/surface_test", "fake_link.hooks.js")
  @link_dest_hooks_file Path.join(
                          @hooks_output_dir,
                          "Mix.Tasks.Compile.SurfaceTest.FakeLink.hooks.js"
                        )
  @link_src_hooks_file_content "let FakeLink = {}\nexport { FakeLink }"

  @hooks_index_file Path.join(@hooks_output_dir, "index.js")

  setup_all do
    conf_before = Application.get_env(:surface, :compiler, [])
    Application.put_env(:surface, :compiler, hooks_output_dir: @hooks_rel_output_dir)

    on_exit(fn ->
      Application.put_env(:surface, :compiler, conf_before)
    end)

    :ok
  end

  setup do
    File.write!(@button_src_hooks_file, @button_src_hooks_file_content)
    File.write!(@link_src_hooks_file, @link_src_hooks_file_content)

    if File.exists?(@hooks_output_dir) do
      File.rm_rf!(@hooks_output_dir)
    end

    on_exit(fn ->
      File.rm_rf!(@hooks_output_dir)
      File.rm_rf!(@button_src_hooks_file)
      File.rm_rf!(@link_src_hooks_file)
    end)

    :ok
  end

  test "copy hooks files to output dir and add header comment" do
    refute File.exists?(@button_dest_hooks_file)
    refute File.exists?(@link_dest_hooks_file)

    run([])

    assert File.read!(@button_dest_hooks_file) == """
           /*
           This file was generated by the Surface compiler.
           */

           let FakeButton = {}
           export { FakeButton }\
           """

    assert File.read!(@link_dest_hooks_file) == """
           /*
           This file was generated by the Surface compiler.
           */

           let FakeLink = {}
           export { FakeLink }\
           """
  end

  test "generate index.js file for hooks" do
    refute File.exists?(@hooks_output_dir)

    run([])

    assert File.read!(@hooks_index_file) =~ """
           /*
           This file was generated by the Surface compiler.
           */

           function ns(hooks, nameSpace) {
             const updatedHooks = {}
             Object.keys(hooks).map(function(key) {
               updatedHooks[`${nameSpace}#${key}`] = hooks[key]
             })
             return updatedHooks
           }

           import * as c1 from "./Mix.Tasks.Compile.SurfaceTest.FakeButton.hooks"
           import * as c2 from "./Mix.Tasks.Compile.SurfaceTest.FakeLink.hooks"

           let hooks = Object.assign(
             ns(c1, "Mix.Tasks.Compile.SurfaceTest.FakeButton"),
             ns(c2, "Mix.Tasks.Compile.SurfaceTest.FakeLink")
           )

           export default hooks
           """
  end

  test "update dest hook file and index.js if src hook file is newer than index.js" do
    refute File.exists?(@hooks_output_dir)

    run([])

    files = [@button_dest_hooks_file, @link_dest_hooks_file, @hooks_index_file]

    assert files_changed?(files, fn -> run([]) end) == [false, false, false]

    mtime = @hooks_index_file |> get_mtime() |> inc_mtime()
    File.write!(@button_src_hooks_file, @button_src_hooks_file_content_modified)
    File.touch!(@button_src_hooks_file, mtime)

    assert files_changed?(files, fn -> run([]) end) == [true, false, false]

    assert File.read!(@button_dest_hooks_file) =~ "let FakeButton = { mounted() {} }"
  end

  test "generate index.js with empty object if there's no hooks available" do
    refute File.exists?(@hooks_output_dir)

    generate_files({[], []})

    assert File.read!(@hooks_index_file) == """
           /*
           This file was generated by the Surface compiler.
           */

           export default {}
           """
  end

  test "removes unused hooks files from output dir and update index.js" do
    refute File.exists?(@hooks_output_dir)

    run([])

    assert File.exists?(@link_dest_hooks_file)

    File.rm!(@link_src_hooks_file)

    assert files_changed?([@hooks_index_file], fn -> run([]) end) == [true]

    refute File.exists?(@link_dest_hooks_file)
  end

  defp inc_mtime(time) do
    time
    |> :calendar.datetime_to_gregorian_seconds()
    |> Kernel.+(1)
    |> :calendar.gregorian_seconds_to_datetime()
  end

  defp get_mtime(file) do
    %File.Stat{mtime: mtime} = File.stat!(file)
    mtime
  end

  defp files_changed?(files, fun) do
    old_contents = Enum.map(files, &File.read!/1)
    fun.()
    new_contents = Enum.map(files, &File.read!/1)
    old_contents |> Enum.zip(new_contents) |> Enum.map(fn {old, new} -> old != new end)
  end
end
