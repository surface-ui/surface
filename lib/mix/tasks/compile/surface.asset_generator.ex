defmodule Mix.Tasks.Compile.Surface.AssetGenerator do
  @moduledoc false

  alias Mix.Task.Compiler.Diagnostic

  @default_hooks_output_dir "assets/js/_hooks"
  @default_css_output_file "assets/css/_components.css"
  @default_tailwind_variants_output_file "assets/css/_tailwind.variants.js"
  @supported_hooks_extensions ~W"js jsx ts tsx" |> Enum.join(",")
  @hooks_tag ".hooks"
  @hooks_extension "#{@hooks_tag}.{#{@supported_hooks_extensions}}"

  def run(components, opts \\ []) do
    hooks_output_dir = Keyword.get(opts, :hooks_output_dir, @default_hooks_output_dir)
    css_output_file = Keyword.get(opts, :css_output_file, @default_css_output_file)
    enable_tailwind_variants = Keyword.get(opts, :enable_tailwind_variants, false)

    tailwind_variants_output_file =
      Keyword.get(opts, :tailwind_variants_output_file, @default_tailwind_variants_output_file)

    env = Keyword.get(opts, :env, Mix.env())
    {js_files, js_diagnostics} = get_colocated_js_files(components)
    generate_js_files(js_files, hooks_output_dir)
    css_diagnostics = generate_css_file(components, css_output_file, env)

    variants_diagnostics =
      generate_variants_file(components, enable_tailwind_variants, tailwind_variants_output_file)

    diagnostics = js_diagnostics ++ css_diagnostics ++ variants_diagnostics
    diagnostics |> Enum.reject(&is_nil/1)
  end

  defp generate_css_file(components, css_output_file, env) do
    dest_file = Path.join([File.cwd!(), css_output_file])

    dest_file_content =
      case File.read(dest_file) do
        {:ok, content} -> content
        _ -> nil
      end

    {content, diagnostics} =
      for mod <- Enum.sort(components, :desc),
          function_exported?(mod, :__style__, 0),
          {_func, %{css: css, vars: vars}} = func_style <- mod.__style__(),
          reduce: {"", []} do
        {content, diagnostics} ->
          css = String.trim_leading(css, "\n")

          {
            ["\n/* ", scope_header(mod, func_style), " */\n\n", vars_comment(vars, env), css | content],
            diagnostics
          }
      end

    content = to_string([header(), "\n" | content])

    if content != dest_file_content do
      dest_file |> Path.dirname() |> File.mkdir_p!()
      File.write!(dest_file, content)
    end

    diagnostics
  end

  defp generate_variants_file(_components, false, _output_file) do
    []
  end

  defp generate_variants_file(components, _enable_tailwind_variants, output_file) do
    dest_file = Path.join([File.cwd!(), output_file])

    dest_file_content =
      case File.read(dest_file) do
        {:ok, content} -> content
        _ -> nil
      end

    # TODO: move the sort outside
    content =
      for mod <- Enum.sort(components, :desc), reduce: [] do
        content ->
          specs = mod.__props__() ++ mod.__data__()
          scope_attr = Surface.Compiler.CSSTranslator.scope_attr(mod)

          variants =
            for spec <- specs, spec.opts[:css_variant] do
              variant_name =
                spec.name
                |> to_string()
                |> String.replace(["_", "!", "?"], fn
                  "_" -> "-"
                  _ -> ""
                end)

              case {spec.type, spec.opts[:values] || spec.opts[:values!]} do
                {:boolean, _} ->
                  """
                      /* #{spec.func} #{spec.name} */
                      plugin(({ addVariant }) => addVariant('#{variant_name}', ['&[#{scope_attr}][data-#{variant_name}]', '[#{scope_attr}][data-#{variant_name}] &[#{scope_attr}]'])),
                      plugin(({ addVariant }) => addVariant('not-#{variant_name}', ['&[s-self][#{scope_attr}]:not([data-#{variant_name}])', '[s-self][#{scope_attr}]:not([data-#{variant_name}]) &[#{scope_attr}]'])),
                  """

                {type, [_ | _] = values} when type in [:atom, :string] ->
                  [
                    "    /* #{spec.func} #{spec.name} */\n",
                    for value <- values do
                      """
                          plugin(({ addVariant }) => addVariant('#{variant_name}-#{value}', ['&[#{scope_attr}][data-#{variant_name}="#{value}"]', '[#{scope_attr}][data-#{variant_name}="#{value}"] &[#{scope_attr}]'])),
                      """
                    end
                  ]
              end
            end

          if variants != [] do
            ["    /* ", inspect(mod), " */\n", variants | content]
          else
            content
          end
      end

    content = [
      header(),
      """


      const plugin = require("tailwindcss/plugin");

      module.exports = {
        plugins: [
      """,
      content,
      """
        ]
      };
      """
    ]

    content = to_string(content)

    if content != dest_file_content do
      dest_file |> Path.dirname() |> File.mkdir_p!()
      File.write!(dest_file, content)
    end

    # TODO: implement disgnostics, if needed
    []
  end

  defp scope_header(mod, {:__module__, %{scope_id: scope_id}}) do
    [inspect(mod), " (", scope_id, ")"]
  end

  defp scope_header(mod, {func, %{scope_id: scope_id}}) do
    [inspect(mod), ".", to_string(func), "/1 (", scope_id, ")"]
  end

  defp generate_js_files(js_files, hooks_output_dir) do
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
