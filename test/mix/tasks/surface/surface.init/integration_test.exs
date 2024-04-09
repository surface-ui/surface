defmodule Mix.Tasks.Surface.Init.IntegrationTest do
  use ExUnit.Case
  @moduletag :integration

  alias Mix.Tasks.Surface.Init.FilePatchers

  setup_all do
    {template_status, template_project_folder} = build_test_project_template("surface_init_test")
    project_folder_patched = "#{template_project_folder}_patched"
    project_folder_unpatched = "#{template_project_folder}_unpatched"

    build_project_from_template(template_status, template_project_folder, project_folder_unpatched,
      on_change: &compile/1
    )

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
        "mix surface.init --catalogue --demo --layouts --tailwind --yes --no-install --dry-run --web-module SurfaceInitTestWeb",
        opts
      )

    assert output == """
           * patching .formatter.exs
           * patching .gitignore
           * patching assets/css/app.css
           * patching assets/js/app.js
           * patching config/config.exs
           * patching config/dev.exs
           * patching lib/surface_init_test_web.ex
           * patching lib/surface_init_test_web/router.ex
           * patching mix.exs
           * creating lib/surface_init_test_web/components/card.ex
           * creating test/surface_init_test_web/components/card_test.exs
           * creating lib/surface_init_test_web/live/demo.ex
           * creating priv/catalogue/surface_init_test_web/components/card_examples.ex
           * creating priv/catalogue/surface_init_test_web/components/card_playground.ex
           * deleting assets/css/phoenix.css
           * creating assets/tailwind.config.js
           * creating lib/surface_init_test_web/templates/page/index.sface
           * deleting lib/surface_init_test_web/templates/page/index.html.heex
           * creating lib/surface_init_test_web/templates/layout/app.sface
           * deleting lib/surface_init_test_web/templates/layout/app.html.heex
           * creating lib/surface_init_test_web/templates/layout/live.sface
           * deleting lib/surface_init_test_web/templates/layout/live.html.heex
           * creating lib/surface_init_test_web/templates/layout/root.sface
           * deleting lib/surface_init_test_web/templates/layout/root.html.heex

           Finished running 41 patches for 24 files.
           41 changes applied, 0 skipped.
           """
  end

  test "surfice.init on an already patched project applies no changes", %{project_folder_patched: project_folder} do
    opts = [cd: project_folder]

    output =
      cmd(
        "mix surface.init --catalogue --demo --layouts --tailwind --yes --no-install --dry-run --web-module SurfaceInitTestWeb",
        opts
      )

    assert compact_output(output) == """
           * patching .formatter.exs (skipped)
           * patching .gitignore (skipped)
           * patching assets/css/app.css (skipped)
           * patching assets/js/app.js (skipped)
           * patching config/config.exs (skipped)
           * patching config/dev.exs (skipped)
           * patching lib/surface_init_test_web.ex (skipped)
           * patching lib/surface_init_test_web/router.ex (skipped)
           * patching mix.exs (skipped)
           * creating lib/surface_init_test_web/components/card.ex (skipped)
           * creating test/surface_init_test_web/components/card_test.exs (skipped)
           * creating lib/surface_init_test_web/live/demo.ex (skipped)
           * creating priv/catalogue/surface_init_test_web/components/card_examples.ex (skipped)
           * creating priv/catalogue/surface_init_test_web/components/card_playground.ex (skipped)
           * deleting assets/css/phoenix.css (skipped)
           * creating assets/tailwind.config.js (skipped)
           * creating lib/surface_init_test_web/templates/page/index.sface (skipped)
           * deleting lib/surface_init_test_web/templates/page/index.html.heex (skipped)
           * creating lib/surface_init_test_web/templates/layout/app.sface (skipped)
           * deleting lib/surface_init_test_web/templates/layout/app.html.heex (skipped)
           * creating lib/surface_init_test_web/templates/layout/live.sface (skipped)
           * deleting lib/surface_init_test_web/templates/layout/live.html.heex (skipped)
           * creating lib/surface_init_test_web/templates/layout/root.sface (skipped)
           * deleting lib/surface_init_test_web/templates/layout/root.html.heex (skipped)

           Finished running 41 patches for 24 files.
           0 changes applied, 41 skipped.
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
    surface_phx_new_version = Application.spec(:phx_new, :vsn) |> to_string()
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
      cmd("mix phx.new #{project_folder} --no-ecto --no-dashboard --no-mailer --install")

      File.write!(project_phx_new_version_file, surface_phx_new_version)

      project_folder
      |> Path.join("mix.exs")
      |> tap(fn path ->
        changed =
          File.read!(path)
          |> String.replace(~s'{:phoenix_live_view, "~> 0.17.5"}', ~s'{:phoenix_live_view, "~> 0.18.18"}')

        File.write!(path, changed)

        web_path = Path.join(project_folder, "lib/surface_init_test_web.ex")
        content = File.read!(web_path)

        new_content =
          content
          |> String.replace(
            "import Phoenix.LiveView.Helpers",
            "import Phoenix.LiveView.Helpers\n      import Phoenix.Component"
          )

        File.write!(web_path, new_content)
      end)
      |> Mix.Tasks.Surface.Init.Patcher.patch_file([add_surface_to_mix_deps()], %{dry_run: false})

      cmd("mix deps.get", cd: project_folder)
    end

    compile_output = cmd("mix compile", cd: project_folder)
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

  defp cmd(str_cmd, opts \\ []) do
    [cmd | args] = String.split(str_cmd)

    case System.cmd(cmd, args, opts) do
      {result, 0} ->
        result

      {result, code} ->
        Mix.shell().info([:red, "exit with code ", code, ", output: \n", :reset, result])
        raise "command `#{str_cmd}` failed"
    end
  end

  defp compile(project_folder) do
    Mix.shell().info([:green, "* compiling ", :reset, project_folder])
    cmd("mix deps.get", cd: project_folder)
    cmd("mix compile", cd: project_folder)
  end

  defp restore(project_folder) do
    cmd("git clean -fd", cd: project_folder)
    cmd("git restore .", cd: project_folder)
  end

  defp surface_init_all(project_folder) do
    restore(project_folder)
    Mix.shell().info([:green, "* patching ", :reset, project_folder])
    cmd("mix surface.init --catalogue --demo --layouts --tailwind --yes --no-install", cd: project_folder)
    compile(project_folder)
  end
end
