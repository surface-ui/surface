defmodule Mix.Tasks.Compile.Surface.AssetGeneratorTest do
  use ExUnit.Case, async: false

  import Mix.Tasks.Compile.Surface.AssetGenerator
  alias Mix.Task.Compiler.Diagnostic

  @components [
    Mix.Tasks.Compile.SurfaceTest.FakeButton,
    Mix.Tasks.Compile.SurfaceTest.FakeLink
  ]

  # JS Hooks

  @hooks_rel_output_dir "tmp/_hooks"
  @hooks_output_dir Path.join(File.cwd!(), @hooks_rel_output_dir)
  @test_components_dir Path.join(File.cwd!(), "test/support/mix/tasks/compile/surface_test")

  @hook_extension Enum.random(~W"js jsx ts tsx")
  @button_src_hooks_file Path.join(@test_components_dir, "fake_button.hooks.#{@hook_extension}")
  @button_dest_hooks_file Path.join(
                            @hooks_output_dir,
                            "Mix.Tasks.Compile.SurfaceTest.FakeButton.hooks.#{@hook_extension}"
                          )
  @button_src_hooks_file_content "let FakeButton = {}\nexport { FakeButton }"
  @button_src_hooks_file_content_modified "let FakeButton = { mounted() {} }\nexport { FakeButton }"

  @link_src_hooks_file Path.join(@test_components_dir, "fake_link.hooks.#{@hook_extension}")
  @other_hook_extension ~W"js jsx ts tsx" |> List.delete(@hook_extension) |> Enum.random()
  @other_link_src_hooks_file Path.join(@test_components_dir, "fake_link.hooks.#{@other_hook_extension}")
  @link_dest_hooks_file Path.join(
                          @hooks_output_dir,
                          "Mix.Tasks.Compile.SurfaceTest.FakeLink.hooks.#{@hook_extension}"
                        )
  @link_src_hooks_file_content "let FakeLink = {}\nexport { FakeLink }"

  @hooks_index_file Path.join(@hooks_output_dir, "index.js")

  # CSS

  @css_rel_output_file "tmp/_components.css"
  @css_output_file Path.join(File.cwd!(), @css_rel_output_file)

  setup do
    File.write!(@button_src_hooks_file, @button_src_hooks_file_content)
    File.write!(@link_src_hooks_file, @link_src_hooks_file_content)

    if File.exists?(@hooks_output_dir) do
      File.rm_rf!(@hooks_output_dir)
    end

    if File.exists?(@css_output_file) do
      File.rm_rf!(@css_output_file)
    end

    on_exit(fn ->
      File.rm_rf!(@hooks_output_dir)
      File.rm_rf!(@button_src_hooks_file)
      File.rm_rf!(@link_src_hooks_file)
      File.rm_rf!(@other_link_src_hooks_file)
      File.rm_rf!(@css_output_file)
    end)

    %{opts: [hooks_output_dir: @hooks_rel_output_dir, css_output_file: @css_rel_output_file]}
  end

  test "generate css file and add header comment", %{opts: opts} do
    refute File.exists?(@css_output_file)

    assert run(@components ++ [Mix.Tasks.Compile.SurfaceTest.FakePanel], opts) == []

    assert File.read!(@css_output_file) == """
           /*
           This file was generated by the Surface compiler.
           */

           /* Mix.Tasks.Compile.SurfaceTest.FakeButton.render/1 (8c9b2e4) */

           .btn[data-s-8c9b2e4] { padding: 10px; color: var(--59c08eb--color); }

           /* Mix.Tasks.Compile.SurfaceTest.FakeButton.func/1 (580c948) */

             .btn-func[data-s-580c948] { padding: var(--81d9fb2--padding); }

           /* Mix.Tasks.Compile.SurfaceTest.FakeLink.render/1 (4e797dd) */

             .link[data-s-4e797dd] { padding: 10px; }

           /* Mix.Tasks.Compile.SurfaceTest.FakePanel.render/1 (2930ca8) */

             .panel[data-s-2930ca8] { padding: 10px; }
           """
  end

  test "update the css file if the content changes", %{opts: opts} do
    refute File.exists?(@css_output_file)

    assert run(@components, opts) == []

    css1 = File.read!(@css_output_file)

    assert run(@components ++ [Mix.Tasks.Compile.SurfaceTest.FakePanel], opts) == []

    css2 = File.read!(@css_output_file)

    assert css1 != css2
  end

  test "don't save the css file if it hasn't change", %{opts: opts} do
    refute File.exists?(@css_output_file)

    assert run(@components, opts) == []

    mtime = @css_output_file |> get_mtime() |> dec_mtime()

    File.touch!(@css_output_file, mtime)

    assert run(@components, opts) == []

    assert get_mtime(@css_output_file) == mtime
  end

  test "validate multiple styles", %{opts: opts} do
    file = to_string(Mix.Tasks.Compile.SurfaceTest.DuplicatedStyle.module_info(:compile)[:source])

    message = """
    scoped CSS style already defined for Mix.Tasks.Compile.SurfaceTest.DuplicatedStyle.render/1 \
    at test/support/mix/tasks/compile/surface_test/duplicated_style.css:1. \
    Scoped styles must be defined either as the first <style> node in the \
    template or in a colocated .css file.
    """

    assert run([Mix.Tasks.Compile.SurfaceTest.DuplicatedStyle], opts) == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: file,
               message: message,
               position: 6,
               severity: :warning
             }
           ]
  end

  test "copy hooks files to output dir and add header comment", %{opts: opts} do
    refute File.exists?(@button_dest_hooks_file)
    refute File.exists?(@link_dest_hooks_file)

    assert run(@components, opts) == []

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

  test "generate index.js file for hooks", %{opts: opts} do
    refute File.exists?(@hooks_output_dir)

    assert run(@components, opts) == []

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

  test "update dest hook file and index.js if src hook file is newer than index.js", %{opts: opts} do
    refute File.exists?(@hooks_output_dir)

    assert run(@components, opts) == []

    files = [@button_dest_hooks_file, @link_dest_hooks_file, @hooks_index_file]

    assert files_changed?(files, fn -> assert run(@components, opts) == [] end) ==
             [
               false,
               false,
               false
             ]

    mtime = @hooks_index_file |> get_mtime() |> inc_mtime()
    File.write!(@button_src_hooks_file, @button_src_hooks_file_content_modified)
    File.touch!(@button_src_hooks_file, mtime)

    assert files_changed?(files, fn -> assert run(@components, opts) == [] end) ==
             [
               true,
               false,
               false
             ]

    assert File.read!(@button_dest_hooks_file) =~ "let FakeButton = { mounted() {} }"
  end

  test "removes unused hooks files from output dir and update index.js", %{opts: opts} do
    refute File.exists?(@hooks_output_dir)

    assert run(@components, opts) == []

    assert File.exists?(@link_dest_hooks_file)

    File.rm!(@link_src_hooks_file)

    assert files_changed?([@hooks_index_file], fn -> run(@components, opts) end) ==
             [
               true
             ]

    refute File.exists?(@link_dest_hooks_file)
  end

  test "returns diagnostic if component has more then 1 hook and uses the first one", %{opts: opts} do
    File.write!(@other_link_src_hooks_file, @link_src_hooks_file_content)
    refute File.exists?(@hooks_output_dir)

    file = to_string(Mix.Tasks.Compile.SurfaceTest.FakeLink.module_info(:compile)[:source])

    [first_extension, second_extension] = Enum.sort([@other_hook_extension, @hook_extension])

    message = """
    component `Mix.Tasks.Compile.SurfaceTest.FakeLink` has 2 hooks files, using the first one
      * `test/support/mix/tasks/compile/surface_test/fake_link.hooks.#{first_extension}`
      * `test/support/mix/tasks/compile/surface_test/fake_link.hooks.#{second_extension}`
    """

    assert run(@components, opts) == [
             %Diagnostic{
               compiler_name: "Surface",
               details: nil,
               file: file,
               message: message,
               position: 1,
               severity: :warning
             }
           ]

    assert File.exists?(
             Path.join(@hooks_output_dir, "Mix.Tasks.Compile.SurfaceTest.FakeLink.hooks.#{first_extension}")
           )

    dest_glob = Path.join(@hooks_output_dir, "Mix.Tasks.Compile.SurfaceTest.FakeLink.hooks.*")
    assert Path.wildcard(dest_glob) |> length() == 1

    File.rm!(Path.join(@test_components_dir, "fake_link.hooks.#{first_extension}"))

    assert files_changed?([@hooks_index_file], fn ->
             assert run(@components, opts) == []
           end) ==
             [false]

    assert File.exists?(
             Path.join(@hooks_output_dir, "Mix.Tasks.Compile.SurfaceTest.FakeLink.hooks.#{second_extension}")
           )

    assert Path.wildcard(dest_glob) |> length() == 1

    File.rm!(Path.join(@test_components_dir, "fake_link.hooks.#{second_extension}"))

    assert files_changed?([@hooks_index_file], fn ->
             assert run(@components, opts) == []
           end) ==
             [true]

    assert Path.wildcard(dest_glob) |> length() == 0
  end

  defp inc_mtime(time) do
    time
    |> :calendar.datetime_to_gregorian_seconds()
    |> Kernel.+(1)
    |> :calendar.gregorian_seconds_to_datetime()
  end

  defp dec_mtime(time) do
    time
    |> :calendar.datetime_to_gregorian_seconds()
    |> Kernel.+(-1)
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
