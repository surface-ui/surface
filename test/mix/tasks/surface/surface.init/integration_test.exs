defmodule Mix.Tasks.Surface.Init.IntegrationTest do
  use ExUnit.Case, async: true
  @moduletag :integration

  alias Mix.Tasks.Surface.Init.FilePatchers

  @phx_new_version "1.7.19"

  setup_all do
    {template_status, template_project_folder} = build_test_project_template("surface_init_test")
    project_folder_patched = "#{template_project_folder}_patched"
    project_folder_unpatched = "#{template_project_folder}_unpatched"

    build_project_from_template(:created, template_project_folder, project_folder_unpatched, on_change: &compile/1)

    build_project_from_template(template_status, template_project_folder, project_folder_patched,
      on_create: &surface_init_all/1,
      on_change: &surface_init_all/1
    )

    %{project_folder: project_folder_unpatched, project_folder_patched: project_folder_patched}
  end

  test "surfice.init on a fresh project applies all changes", %{project_folder: project_folder} do
    opts = [cd: project_folder]

    output =
      cmd(
        "mix surface.init --catalogue --demo --layouts --yes --no-install --web-module SurfaceInitTestWeb",
        opts
      )

    assert output =~ """
           * patching .formatter.exs
           * patching .gitignore
           * patching Dockerfile
           * patching assets/css/app.css
           * patching assets/js/app.js
           * patching assets/tailwind.config.js
           * patching config/config.exs
           * patching config/dev.exs
           * patching lib/surface_init_test_web.ex
           * patching lib/surface_init_test_web/components/layouts.ex
           * patching lib/surface_init_test_web/router.ex
           * patching mix.exs
           * creating lib/surface_init_test_web/components/card.ex
           * creating test/surface_init_test_web/components/card_test.exs
           * creating lib/surface_init_test_web/live/demo.ex
           * creating priv/catalogue/surface_init_test_web/components/card_examples.ex
           * creating priv/catalogue/surface_init_test_web/components/card_playground.ex
           * creating lib/surface_init_test_web/components/layouts/app.sface
           * deleting lib/surface_init_test_web/components/layouts/app.html.heex
           * creating lib/surface_init_test_web/components/layouts/root.sface
           * deleting lib/surface_init_test_web/components/layouts/root.html.heex

           Finished running 31 patches for 21 files.
           31 changes applied, 0 skipped.
           """

    compile(project_folder, warnings_as_errors: true)
    cmd("mix test --warnings-as-errors", opts)
  end

  test "surfice.init on an already patched project applies no changes", %{project_folder_patched: project_folder} do
    opts = [cd: project_folder]

    output =
      cmd(
        "mix surface.init --catalogue --demo --layouts --yes --no-install --dry-run --web-module SurfaceInitTestWeb",
        opts
      )

    assert compact_output(output) =~ """
           * patching .formatter.exs (skipped)
           * patching .gitignore (skipped)
           * patching Dockerfile (skipped)
           * patching assets/css/app.css (skipped)
           * patching assets/js/app.js (skipped)
           * patching assets/tailwind.config.js (skipped)
           * patching config/config.exs (skipped)
           * patching config/dev.exs (skipped)
           * patching lib/surface_init_test_web.ex (skipped)
           * patching lib/surface_init_test_web/components/layouts.ex (skipped)
           * patching lib/surface_init_test_web/router.ex (skipped)
           * patching mix.exs (skipped)
           * creating lib/surface_init_test_web/components/card.ex (skipped)
           * creating test/surface_init_test_web/components/card_test.exs (skipped)
           * creating lib/surface_init_test_web/live/demo.ex (skipped)
           * creating priv/catalogue/surface_init_test_web/components/card_examples.ex (skipped)
           * creating priv/catalogue/surface_init_test_web/components/card_playground.ex (skipped)
           * creating lib/surface_init_test_web/components/layouts/app.sface (skipped)
           * deleting lib/surface_init_test_web/components/layouts/app.html.heex (skipped)
           * creating lib/surface_init_test_web/components/layouts/root.sface (skipped)
           * deleting lib/surface_init_test_web/components/layouts/root.html.heex (skipped)

           Finished running 31 patches for 21 files.
           0 changes applied, 31 skipped.
           It looks like this project has already been patched.
           """
  end

  defp add_surface_to_mix_deps do
    %{
      name: "Add `surface` dependency",
      patch: &FilePatchers.MixExs.add_dep(&1, ":surface", ~s(path: "#{File.cwd!()}", override: true)),
      instructions: ""
    }
  end

  # TODO: Remove this patch whenever phx.new starts generating the project
  # without warnings related to API changes in Gettext v0.26.
  def replace_gettext_in_mix_deps do
    %{
      name: "Replace `gettext` dependency",
      instructions: "",
      patch:
        &FilePatchers.Text.replace_text(
          &1,
          ~s({:gettext, "~> 0.20"}),
          ~s({:gettext, "~> 0.25.0"}),
          ~s({:gettext, "~> 0.25.0"})
        )
    }
  end

  defp compact_output(output) do
    output
    |> String.split(["\n"])
    |> Enum.reduce([], fn
      "\e[1A" <> text, [_ | acc] -> [text | acc]
      text, acc -> [text | acc]
    end)
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp build_test_project_template(project_name) do
    if project_name in ["", nil], do: raise("project name cannot be empty")

    project_folder = Path.join(System.tmp_dir!(), project_name)
    project_exists? = File.exists?(project_folder)
    surface_phx_new_version = @phx_new_version
    project_phx_new_version_file = Path.join(project_folder, ".phx_new_version")

    project_phx_new_version =
      case File.read(project_phx_new_version_file) do
        {:ok, text} -> text
        _ -> nil
      end

    create_project? = !project_exists? or project_phx_new_version != surface_phx_new_version

    if create_project? do
      Mix.shell().info([
        :cyan,
        "INFO: temp folder `#{project_name}` not found or outdated. Rebuilding it using phx.new v#{surface_phx_new_version}",
        :reset
      ])

      Mix.shell().info([:green, "* creating ", :reset, project_folder])
      File.rm_rf!(project_folder)
      phx_new(project_folder)

      File.write!(project_phx_new_version_file, surface_phx_new_version)

      mix_file = Path.join(project_folder, "mix.exs")

      Mix.Tasks.Surface.Init.Patcher.patch_file(
        mix_file,
        [add_surface_to_mix_deps(), replace_gettext_in_mix_deps()],
        %{dry_run: false}
      )

      cmd("mix deps.get", cd: project_folder)
      cmd("mix phx.gen.release --docker", cd: project_folder)
    end

    compile_output = cmd("mix compile --warnings-as-errors", cd: project_folder)
    compiled? = String.contains?(compile_output, "Compiling")

    status =
      cond do
        create_project? -> :created
        compiled? -> :recompiled
        true -> :noop
      end

    {status, project_folder}
  end

  defp build_project_from_template(template_status, template_project_folder, project_folder, callbacks) do
    if template_status == :created or !File.exists?(project_folder) do
      Mix.shell().info([:green, "* creating ", :reset, project_folder, :reset])
      File.rm_rf!(project_folder)
      File.cp_r!(template_project_folder, project_folder)
      compile(project_folder)
      cmd("git init .", cd: project_folder)
      cmd("git add .", cd: project_folder)
      callbacks[:on_create] && callbacks[:on_create].(project_folder)
    end

    if template_status == :recompiled do
      callbacks[:on_change] && callbacks[:on_change].(project_folder)
    end
  end

  defp phx_new(project_folder) do
    phx_new_script =
      """
      Mix.install([{:phx_new, "#{@phx_new_version}"}])
      Mix.Task.run("phx.new", ["#{project_folder}", "--no-ecto", "--no-dashboard", "--no-mailer", "--no-install"])
      """

    cmd("elixir", ["--eval", phx_new_script])
  end

  defp cmd(str_cmd, opts) do
    if Keyword.keyword?(opts) do
      [cmd | args] = String.split(str_cmd)
      cmd(cmd, args, opts)
    else
      cmd(str_cmd, opts, [])
    end
  end

  defp cmd(cmd, args, opts) do
    case System.cmd(cmd, args, opts) do
      {result, 0} ->
        result

      {result, code} ->
        Mix.shell().info([:red, "exit with code ", code, ", output: \n", :reset, result])
        raise "command `#{cmd} #{args}` failed"
    end
  end

  defp compile(project_folder, opts \\ []) do
    Mix.shell().info([:green, "* compiling ", :reset, project_folder])
    cmd("mix deps.get", cd: project_folder)

    if opts[:warnings_as_errors] do
      cmd("mix compile --warnings-as-errors", cd: project_folder)
    else
      cmd("mix compile", cd: project_folder)
    end
  end

  defp restore(project_folder) do
    cmd("git clean -fd", cd: project_folder)
    cmd("git restore .", cd: project_folder)
  end

  defp surface_init_all(project_folder) do
    restore(project_folder)
    Mix.shell().info([:green, "* patching ", :reset, project_folder])
    cmd("mix surface.init --catalogue --demo --layouts --yes --no-install", cd: project_folder)
    compile(project_folder)
  end
end
