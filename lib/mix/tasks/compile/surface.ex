defmodule Mix.Tasks.Compile.Surface do
  @moduledoc """
  Generate CSS and JS/TS assets for components.
  """

  use Mix.Task
  @recursive true

  alias Mix.Task.Compiler.Diagnostic

  @default_hooks_output_dir "assets/js/_hooks"
  @supported_hooks_extensions ~W"js jsx ts tsx" |> Enum.join(",")
  @hooks_tag ".hooks"
  @hooks_extension "#{@hooks_tag}.{#{@supported_hooks_extensions}}"

  @switches [
    return_errors: :boolean,
    warnings_as_errors: :boolean
  ]

  @doc false
  def run(args) do
    {compile_opts, _argv, _err} = OptionParser.parse(args, strict: @switches)

    {js_files, _css_files, diagnostics} = get_colocated_assets()
    generate_files(js_files)

    case Enum.reject(diagnostics, &is_nil/1) do
      [] ->
        {:noop, []}

      diagnostics ->
        if !compile_opts[:return_errors], do: print_diagnostics(diagnostics)
        status = status(compile_opts[:warnings_as_errors], diagnostics)

        {status, diagnostics}
    end
  end

  @doc false
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
    for [app] <- applications(),
        mod <- app_modules(app),
        module_loaded?(mod),
        function_exported?(mod, :component_type, 0),
        reduce: {[], [], []} do
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

  defp app_modules(app) do
    if Application.ensure_loaded(app) == :ok do
      app
      |> Application.app_dir()
      |> Path.join("ebin/Elixir.*.beam")
      |> Path.wildcard()
      |> Enum.map(&beam_to_module/1)
    else
      []
    end
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end

  defp applications do
    # If we invoke :application.loaded_applications/0,
    # it can error if we don't call safe_fixtable before.
    # Since in both cases we are reaching over the
    # application controller internals, we choose to match
    # for performance.
    apps = :ets.match(:ac_tab, {{:loaded, :"$1"}, :_})

    # Make sure we have the project's app (it might not be there when first compiled)
    apps = [[Mix.Project.config()[:app]] | apps]

    apps
    |> MapSet.new()
    |> MapSet.to_list()
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

  defp print_diagnostics(diagnostics) do
    for %Diagnostic{message: message, severity: :warning} <- diagnostics do
      IO.warn(message, [])
    end
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

  defp status(warnings_as_errors, diagnostics) do
    cond do
      Enum.any?(diagnostics, &(&1.severity == :error)) -> :error
      warnings_as_errors && Enum.any?(diagnostics, &(&1.severity == :warning)) -> :error
      true -> :ok
    end
  end
end
