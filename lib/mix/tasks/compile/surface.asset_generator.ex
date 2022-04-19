defmodule Mix.Tasks.Compile.Surface.AssetGenerator do
  @moduledoc false

  alias Mix.Task.Compiler.Diagnostic

  @default_hooks_output_dir "assets/js/_hooks"
  @supported_hooks_extensions ~W"js jsx ts tsx" |> Enum.join(",")
  @hooks_tag ".hooks"
  @hooks_extension "#{@hooks_tag}.{#{@supported_hooks_extensions}}"

  def run() do
    {js_files, _css_files, diagnostics} = get_colocated_assets()
    generate_files(js_files)
    diagnostics |> Enum.reject(&is_nil/1)
  end

  def generate_files(js_files) do
    opts = Application.get_env(:surface, :compiler, [])

    hooks_output_dir = Keyword.get(opts, :hooks_output_dir, @default_hooks_output_dir)
    js_output_dir = Path.join([File.cwd!(), hooks_output_dir])
    index_file = Path.join([js_output_dir, "index.js"])

    File.mkdir_p!(js_output_dir)

    unused_hooks_files = delete_unused_hooks_files!(js_output_dir, js_files)

    index_file_time =
      case File.stat(index_file) do
        {:ok, %File.Stat{mtime: time}} -> time
        _ -> nil
      end

    update_index? =
      for {src_file, dest_file_name} <- js_files,
          dest_file = Path.join(js_output_dir, dest_file_name),
          {:ok, %File.Stat{mtime: time}} <- [File.stat(src_file)],
          !File.exists?(dest_file) or time > index_file_time,
          reduce: false do
        _ ->
          content = [header(), "\n\n", File.read!(src_file)]
          File.write!(dest_file, content)
          true
      end

    if !index_file_time or update_index? or unused_hooks_files != [] do
      File.write!(index_file, index_content(js_files))
    end
  end

  defp get_colocated_assets() do
    for mod <- components(), module_loaded?(mod), reduce: {[], [], []} do
      {js_files, css_files, diagnostics} ->
        component_file = mod.module_info() |> get_in([:compile, :source]) |> to_string()
        base_file = component_file |> Path.rootname()
        base_name = inspect(mod)
        {js_file, new_diagnostic} = js_file(base_name, base_file, component_file)

        js_files =
          if js_file != nil do
            dest_js_file = "#{base_name}#{@hooks_tag}#{Path.extname(js_file)}"

            [{js_file, dest_js_file} | js_files]
          else
            js_files
          end

        css_file = "#{base_file}.css"
        dest_css_file = "#{base_name}.css"

        css_files = if File.exists?(css_file), do: [{css_file, dest_css_file} | css_files], else: css_files

        {js_files, css_files, [new_diagnostic | diagnostics]}
    end
  end

  defp js_file(base_name, base_file, component_file) do
    hooks_files = Path.wildcard("#{base_file}#{@hooks_extension}") |> Enum.sort()
    hooks_count = length(hooks_files)

    diagnostic =
      if hooks_count > 1 do
        file_messages =
          hooks_files
          |> Enum.map(&"* `#{Path.relative_to_cwd(&1)}`")

        message = """
        component `#{base_name}` has #{hooks_count} hooks files, using the first one
          #{Enum.join(file_messages, "\n  ")}
        """

        warning(message, component_file, 1)
      end

    {List.first(hooks_files), diagnostic}
  end

  defp index_content([]) do
    """
    #{header()}

    export default {}
    """
  end

  defp index_content(js_files) do
    files = js_files |> Enum.sort() |> Enum.with_index(1)

    {hooks, imports} =
      for {{_file, dest_file}, index} <- files, reduce: {[], []} do
        {hooks, imports} ->
          namespace = Regex.replace(~r/#{@hooks_tag}.*$/, dest_file, "")
          var = "c#{index}"
          hook = ~s[ns(#{var}, "#{namespace}")]
          imp = ~s[import * as #{var} from "./#{namespace}.hooks"]
          {[hook | hooks], [imp | imports]}
      end

    hooks = Enum.reverse(hooks)
    imports = Enum.reverse(imports)

    """
    #{header()}

    function ns(hooks, nameSpace) {
      const updatedHooks = {}
      Object.keys(hooks).map(function(key) {
        updatedHooks[`${nameSpace}#${key}`] = hooks[key]
      })
      return updatedHooks
    }

    #{Enum.join(imports, "\n")}

    let hooks = Object.assign(
      #{Enum.join(hooks, ",\n  ")}
    )

    export default hooks
    """
  end

  defp delete_unused_hooks_files!(js_output_dir, js_files) do
    used_files = Enum.map(js_files, fn {_, dest_file} -> Path.join(js_output_dir, dest_file) end)

    all_files =
      js_output_dir
      |> Path.join("*#{@hooks_extension}")
      |> Path.wildcard()

    unsused_files = all_files -- used_files
    Enum.each(unsused_files, &File.rm!/1)
    unsused_files
  end

  defp components() do
    project_app = Mix.Project.config()[:app]
    :ok = Application.ensure_loaded(project_app)
    project_deps_apps = Application.spec(project_app, :applications) || []
    opts = Application.get_env(:surface, :compiler, [])
    only_web_namespace = Keyword.get(opts, :only_web_namespace, false)

    for app <- [project_app | project_deps_apps],
        deps_apps = Application.spec(app)[:applications] || [],
        app in [:surface, project_app] or :surface in deps_apps,
        prefix = app_beams_prefix(app, project_app, only_web_namespace),
        {dir, files} = app_beams_dir_and_files(app),
        file <- files,
        List.starts_with?(file, prefix) do
      :filename.join(dir, file)
    end
    |> Enum.chunk_every(50)
    |> Task.async_stream(fn files ->
      for file <- files,
          {:ok, {_, [{_, chunk} | _]}} = :beam_lib.chunks(file, ['Attr']),
          chunk |> :erlang.binary_to_term() |> Keyword.get(:component_type) do
        file |> Path.basename(".beam") |> String.to_atom()
      end
    end)
    |> Enum.flat_map(fn {:ok, result} -> result end)
  end

  defp app_beams_prefix(app, project_app, only_web_namespace) do
    if only_web_namespace and app == project_app do
      Mix.Phoenix.base()
      |> Mix.Phoenix.web_module()
      |> Module.concat(".")
      |> to_charlist()
    else
      'Elixir.'
    end
  end

  defp app_beams_dir_and_files(app) do
    dir =
      app
      |> Application.app_dir()
      |> Path.join("ebin")
      |> String.to_charlist()

    {:ok, files} = :file.list_dir(dir)
    {dir, files}
  end

  defp module_loaded?(module) do
    match?({:module, _mod}, Code.ensure_compiled(module))
  end

  defp header() do
    """
    /*
    This file was generated by the Surface compiler.
    */\
    """
  end

  defp warning(message, file, line) do
    # TODO: Provide column information in diagnostic once we depend on Elixir v1.13+
    %Diagnostic{
      message: message,
      file: file,
      position: line,
      severity: :warning,
      compiler_name: "Surface"
    }
  end
end
