defmodule Mix.Tasks.Compile.Surface.AssetGenerator do
  @moduledoc false

  alias Mix.Task.Compiler.Diagnostic
  require Logger

  @env Mix.env()
  @default_hooks_output_dir "assets/js/_hooks"
  @default_css_output_file "assets/css/_components.css"
  @supported_hooks_extensions ~W"js jsx ts tsx" |> Enum.join(",")
  @hooks_tag ".hooks"
  @hooks_extension "#{@hooks_tag}.{#{@supported_hooks_extensions}}"

  @default_wait_assets_timeout 2000
  @wait_assets_delay 25

  def run(components, opts \\ []) do
    hooks_output_dir = Keyword.get(opts, :hooks_output_dir, @default_hooks_output_dir)
    css_output_file = Keyword.get(opts, :css_output_file, @default_css_output_file)
    code_reload_config = Keyword.get(opts, :code_reload, [])

    wait_for_assets_timeout =
      Keyword.get(code_reload_config, :wait_for_assets_timeout, @default_wait_assets_timeout)

    assets_depending_on_css_output = Keyword.get(code_reload_config, :assets_depending_on_css_output, [])
    assets_depending_on_hooks_output = Keyword.get(code_reload_config, :assets_depending_on_hooks_output, [])
    env = Keyword.get(opts, :env, @env)
    {js_files, js_diagnostics} = get_colocated_js_files(components)
    js_output_dir = Path.join([File.cwd!(), hooks_output_dir])
    index_js_file = Path.join([js_output_dir, "index.js"])

    generate_js_files(js_files, js_output_dir, index_js_file)
    {css_diagnostics, signatures} = generate_css_file(components, css_output_file, env)

    maybe_wait_for_assets_to_rebuild(
      css_output_file,
      index_js_file,
      wait_for_assets_timeout,
      assets_depending_on_css_output,
      assets_depending_on_hooks_output
    )

    diagnostics = js_diagnostics ++ css_diagnostics
    {Enum.reject(diagnostics, &is_nil/1), signatures}
  end

  defp maybe_wait_for_assets_to_rebuild(css_output_file, index_js_file, timeout, css_files, js_files) do
    if on_code_reload?() do
      max_tries = Integer.floor_div(timeout, @wait_assets_delay)
      wait_for_assets_to_rebuild(css_output_file, index_js_file, css_files, js_files, max_tries, max_tries)
    end
  end

  defp wait_for_assets_to_rebuild(css_output_file, index_js_file, css_files, js_files, max_tries, n_tries) do
    outdated_css_files = outdated_files(css_output_file, css_files)
    outdated_js_files = outdated_files(index_js_file, js_files)

    if outdated_css_files != [] or outdated_js_files != [] do
      if n_tries == max_tries do
        Logger.info("Waiting for assets to be rebuilt...")
      end

      if n_tries > 0 do
        Process.sleep(@wait_assets_delay)

        wait_for_assets_to_rebuild(
          css_output_file,
          index_js_file,
          outdated_css_files,
          outdated_js_files,
          max_tries,
          n_tries - 1
        )
      else
        files = Enum.map_join(outdated_css_files ++ outdated_js_files, "\n", &"  * #{&1}")

        message = """
        the following assets were not rebuilt:

        #{files}

        Make sure you have your phoenix watchers properly set up for development so those assets \
        are rebuilt on code changes, otherwise they may be outdated after code reloading.

        If you don't want the surface compiler to wait for assets during development, remove the \
        files from the :assets_depending_on_css_output and :assets_depending_on_hooks_output options in \
        your surface's compiler config.
        """

        Logger.warn(message)
      end
    end
  end

  defp outdated_files(source_file, files) do
    if File.exists?(source_file) do
      Enum.filter(files, fn file -> file_outdated?(source_file, file) end)
    else
      []
    end
  end

  defp file_outdated?(source_file, dest_file) do
    with {:ok, %File.Stat{mtime: source_time}} <- File.stat(source_file),
         {:ok, %File.Stat{mtime: dest_time}} <- File.stat(dest_file) do
      dest_time < source_time
    else
      _ -> true
    end
  end

  defp on_code_reload? do
    Process.whereis(Phoenix.CodeReloader.Server) != nil
  end

  defp generate_css_file(components, css_output_file, env) do
    dest_file = Path.join([File.cwd!(), css_output_file])

    dest_file_content =
      case File.read(dest_file) do
        {:ok, content} -> content
        _ -> nil
      end

    # TODO: after implementing scoped styles per file (instead of per module), if on_code_reload?,
    # re-read the css file so we don't need to introspect the module.
    {content, _, diagnostics, signatures} =
      for mod <- Enum.sort(components, :desc),
          function_exported?(mod, :__style__, 0),
          {func, %{css: css, scope_id: scope_id, vars: vars, file: file} = style} = func_style <- mod.__style__(),
          reduce: {"", nil, [], %{}} do
        {content, last_mod_func_style, diagnostics, signatures} ->
          css = String.trim_leading(css, "\n")
          component_header = [inspect(mod), ".", to_string(func), "/1 (", scope_id, ")"]

          signatures =
            if Path.extname(file) == ".css" and not Map.has_key?(signatures, file) do
              Map.put(signatures, file, Surface.Compiler.CSSTranslator.structure_signature(style))
            else
              signatures
            end

          {
            ["\n/* ", component_header, " */\n\n", vars_comment(vars, env), css | content],
            {mod, func_style},
            validate_multiple_styles({mod, func_style}, last_mod_func_style) ++ diagnostics,
            signatures
          }
      end

    content = to_string([header(), "\n" | content])

    if content != dest_file_content do
      dest_file |> Path.dirname() |> File.mkdir_p!()
      File.write!(dest_file, content)
    end

    {diagnostics, signatures}
  end

  defp generate_js_files(js_files, js_output_dir, index_file) do
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

  defp get_colocated_js_files(components) do
    for mod <- components, module_loaded?(mod), reduce: {[], []} do
      {js_files, diagnostics} ->
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

        {js_files, [new_diagnostic | diagnostics]}
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

  defp validate_multiple_styles({mod, {func, style}}, {mod, {func, other_style}}) do
    position = "#{Path.relative_to_cwd(style.file)}:#{style.line}"

    message = """
    scoped CSS style already defined for #{inspect(mod)}.#{func}/1 at #{position}. \
    Scoped styles must be defined either as the first <style> node in \
    the template or in a colocated .css file.
    """

    [warning(message, other_style.file, other_style.line)]
  end

  defp validate_multiple_styles(_, _) do
    []
  end

  defp vars_comment(vars, env) do
    comment =
      vars
      |> Enum.reverse()
      |> Enum.reduce([], fn {var, {expr, _meta}}, acc ->
        ["  #{var}: `#{expr}`\n" | acc]
      end)

    if comment == [] or env == :prod do
      ""
    else
      ["/* vars:\n", comment, "*/\n\n"]
    end
  end
end
