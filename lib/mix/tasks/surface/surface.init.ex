defmodule Mix.Tasks.Surface.Init do
  @moduledoc """
  Configures Surface on a phoenix project.

      $ mix surface.init

  ## Important note

  This task is still **experimental**. Make sure you have committed your work or have a proper
  backup before running it. As it may change a few files in the project, it's recommended to
  have a safe way to rollback the changes in case anything goes wrong.

  ## Options

    * `--catalogue` - Configures the experimental Surface Catalogue for the project, which
      will be available at the `/catalogue` route. For more information
      see: https://github.com/surface-ui/surface_catalogue.

    * `--demo` - Generates a sample `<Hero>` component. When used together with the `--catalogue`
      option, it additionally generates two catalogue examples and a playground for the component.

    * `--no-formatter` - do not configure the Surface formatter.

  """

  use Mix.Task

  alias Mix.Tasks.Surface.Init.FilePatcher
  alias Mix.Tasks.Surface.Init.ExPatcher
  alias Mix.Tasks.Surface.Init.Patches

  @switches [
    formatter: :boolean,
    catalogue: :boolean,
    demo: :boolean
  ]

  @default_opts [
    formatter: true,
    catalogue: false,
    demo: false
  ]

  @experimental_warning """
  This task will change existing files in your project.

  Make sure you commit your work before running it, especially if this is not a fresh phoenix project.
  """

  @doc false
  def run(args) do
    opts = parse_opts(args)

    Mix.shell().info([:yellow, "\nNote: ", :reset, @experimental_warning])

    unless Mix.shell().yes?("Do you want to continue?") do
      exit(:normal)
    end

    %{
      context_app: context_app,
      web_module: web_module,
      web_module_path: web_module_path,
      web_path: web_path
    } = project_info()

    default_patches = [
      {"mix.exs", Patches.mix_compilers()},
      {"config/dev.exs",
       [
         Patches.endpoint_config_reloadable_compilers(context_app, web_module),
         Patches.endpoint_config_live_reload_patterns(context_app, web_module, web_path)
       ]},
      {web_module_path, Patches.web_view_config(web_module)},
      {"assets/js/app.js", Patches.js_hooks()}
    ]

    formatter_patches =
      if opts[:formatter] do
        [
          {".formatter.exs",
           [
             Patches.formatter_surface_inputs(),
             Patches.formatter_import_deps()
           ]}
        ]
      else
        []
      end

    gettext_patches =
      if using_gettext?(web_path, web_module) do
        [{"config/config.exs", [Patches.config_error_tag(web_module)]}]
      else
        []
      end

    catalogue_patches =
      if opts[:catalogue] do
        [
          {"mix.exs",
           [
             Patches.mix_exs_add_surface_catalogue_dep(),
             Patches.mix_exs_catalogue_update_elixirc_paths()
           ]},
          {"config/dev.exs", Patches.endpoint_config_live_reload_patterns_for_catalogue(context_app, web_module)},
          {"#{web_path}/router.ex", Patches.catalogue_router_config(web_module)}
        ]
      else
        []
      end

    patches = default_patches ++ formatter_patches ++ gettext_patches ++ catalogue_patches

    patches
    |> FilePatcher.patch_files()
    |> FilePatcher.print_patch_results()
  end

  defp parse_opts(args) do
    {opts, _parsed} = OptionParser.parse!(args, strict: @switches)
    Keyword.merge(@default_opts, opts)
  end

  defp project_info() do
    context_app = Mix.Phoenix.context_app()
    web_path = Mix.Phoenix.web_path(context_app)
    base = Module.concat([Mix.Phoenix.base()])
    web_module = Mix.Phoenix.web_module(base)
    web_module_path = web_module_path(context_app)

    %{
      context_app: context_app,
      web_module: web_module,
      web_module_path: web_module_path,
      web_path: web_path
    }
  end

  defp web_module_path(ctx_app) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    [lib_prefix, web_dir] = Path.split(web_prefix)
    Path.join(lib_prefix, "#{web_dir}.ex")
  end

  defp using_gettext?(web_path, web_module) do
    file = Path.join(web_path, "views/error_helpers.ex")
    error_helper = Module.concat(web_module, ErrorHelpers)

    file
    |> ExPatcher.parse_file!()
    |> ExPatcher.enter_defmodule(error_helper)
    |> ExPatcher.enter_def(:translate_error)
    |> ExPatcher.find_code_containing("Gettext.dngettext")
    |> ExPatcher.valid?()
  end
end
