defmodule Mix.Tasks.Compile.Surface.Definitions do
  @moduledoc false

  @output_dir "#{Mix.Project.build_path()}/definitions/"

  # TODO: Receive `components` when `all_components` has been moved out
  def run(_components, opts \\ []) do
    generate_definitions? = Keyword.get(opts, :generate_definitions, true)

    if generate_definitions? do
      do_run(all_components(), opts)
    else
      []
    end
  end

  defp do_run(components, _opts) do
    generate_definitions(components)
    []
  end

  defp generate_definitions(components) do
    definitions =
      for %{type: type} = spec <- components do
        case type do
          :surface ->
            %{
              name: spec.module,
              alias: get_alias(spec.module)
            }

          type when type in [:def, :defp] ->
            %{
              name: "#{spec.module}.#{spec.func}",
              alias: ".#{spec.func}"
            }
        end
      end
      |> Enum.sort_by(& &1.name)

    components_by_name =
      for %{type: type} = spec <- components, into: %{} do
        case type do
          :surface ->
            {spec.module, spec}

          type when type in [:def, :defp] ->
            {"#{spec.module}.#{spec.func}", spec}
        end
      end

    File.mkdir_p!(@output_dir)

    # TODO: remove `pretty` before release
    components_file = Path.join(@output_dir, "components.json")
    components_content = Jason.encode!(definitions, pretty: true)
    File.write!(components_file, components_content)

    components_by_name_file = Path.join(@output_dir, "components_by_name.json")
    components_by_name_content = Jason.encode!(components_by_name, pretty: true)
    File.write!(components_by_name_file, components_by_name_content)
  end

  defp get_doc(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _moduledoc_anno, _language, "text/markdown", %{"en" => docs}, _meta, _docs} ->
        docs

      _ ->
        nil
    end
  end

  defp get_functions_docs(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _moduledoc_anno, _language, "text/markdown", _mod_docs, _meta, func_docs} ->
        for {{:function, func, 1}, _line, _sig, %{"en" => doc}, _meta} <- func_docs, into: %{} do
          {func, doc}
        end

      _ ->
        %{}
    end
  end

  defp get_alias(component) do
    # component
    # |> Module.split()
    # |> Enum.take(-1)
    # |> Module.concat()
    # |> inspect()
    component
    |> String.split(".")
    |> List.last()
  end

  defp get_props(module) do
    if ensure_loaded?(module) and function_exported?(module, :__props__, 0) do
      for prop <- module.__props__(), prop.type != :children do
        %{
          name: "#{to_string(prop.name)}",
          type: prop.type,
          doc: prop.doc,
          opts: "#{inspect(prop.type)}#{format_opts(prop.opts_ast)}",
          line: prop.line
        }
      end
    else
      []
    end
  end

  defp format_opts(opts_ast) do
    if opts_ast == [] do
      ""
    else
      str =
        opts_ast
        |> Macro.to_string()
        |> String.slice(1..-2//1)

      ", " <> str
    end
  end

  defp ensure_loaded?(Elixir), do: false
  defp ensure_loaded?(mod), do: match?({:module, _}, Code.ensure_compiled(mod))

  # TODO: Move this function to Mix.Tasks.Compile.Surface, accumutale all list and pass
  # each one based on the requirements of each generator.
  defp all_components do
    project_app = Mix.Project.config()[:app]
    :ok = Application.ensure_loaded(project_app)
    {:ok, dirs} = :file.list_dir(~c"#{Mix.Project.build_path()}/lib")
    apps = Enum.map(dirs, fn dir -> :"#{dir}" end)

    for app <- apps,
        deps_apps = Application.spec(app)[:applications] || [],
        app in [:phoenix_live_view, :surface] or
          Enum.any?(deps_apps, fn dep -> dep in [:phoenix_live_view, :surface] end),
        {dir, files} = app_beams_dir_and_files(app),
        file <- files,
        List.starts_with?(file, ~c"Elixir.") do
      :filename.join(dir, file)
    end
    |> Enum.chunk_every(50)
    |> Task.async_stream(fn files ->
      for file <- files,
          {:ok, {mod, [{:attributes, attributes}, {:exports, exports}]}} =
            :beam_lib.chunks(file, [:attributes, :exports]),
          reduce: [] do
        components ->
          source = Path.relative_to_cwd(to_string(mod.module_info()[:compile][:source]))

          {components, privates} =
            case Keyword.get(exports, :__components__) do
              nil ->
                {components, []}

              0 ->
                function_components = mod.__components__()

                docs =
                  if function_components != [] do
                    get_functions_docs(mod)
                  else
                    %{}
                  end

                Enum.reduce(function_components, {components, []}, fn {func, spec}, {components, privates} ->
                  comp = %{
                    type: spec.kind,
                    module: inspect(mod),
                    func: func,
                    docs: docs[func],
                    attrs: attrs_to_specs(spec.attrs),
                    source: source,
                    line: spec.line
                  }

                  case spec.kind do
                    :def -> {[comp | components], privates}
                    :defp -> {components, [comp | privates]}
                  end
                end)
            end

          case Keyword.get(attributes, :component_type) do
            nil ->
              components

            _ ->
              comp = %{
                type: :surface,
                module: inspect(mod),
                docs: get_doc(mod),
                props: get_props(mod),
                source: source,
                privates: privates,
                aliases: map_aliases(Keyword.get(attributes, :surface_aliases, [])),
                imports: components_from_imports(Keyword.get(attributes, :surface_imports, []))
                # TODO: line
              }

              [comp | components]
          end
      end
    end)
    |> Enum.flat_map(fn {:ok, result} -> result end)
  end

  defp map_aliases(aliases) do
    Map.new(aliases, fn {key, value} ->
      {inspect(key), inspect(value)}
    end)
  end

  defp components_from_imports(surface_imports) do
    for {mod, imports} <- surface_imports,
        function_exported?(mod, :__components__, 0),
        components = mod.__components__(),
        func <- imports,
        Map.has_key?(components, func),
        into: %{} do
      {func, "#{inspect(mod)}.#{func}"}
    end
  end

  defp attrs_to_specs(attrs) do
    Enum.map(attrs, fn attr ->
      %{
        line: attr.line,
        name: attr.name,
        type: inspect(attr.type),
        doc: attr.doc,
        required: attr.required
      }
    end)
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
end
