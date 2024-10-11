defmodule Mix.Tasks.Compile.Surface.Definitions do
  @moduledoc false

  @output_dir "#{Mix.Project.build_path()}/definitions/"

  def run(components, opts \\ []) do
    generate_definitions? = Keyword.get(opts, :generate_definitions, true)

    if generate_definitions? do
      do_run(components, opts)
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
      for component <- Enum.sort(components) do
        %{
          name: inspect(component),
          alias: get_alias(component)
        }
      end

    components_by_name =
      for component <- Enum.sort(components), into: %{} do
        spec = %{
          docs: get_doc(component),
          props: get_props(component),
          source: Path.relative_to_cwd(to_string(component.module_info()[:compile][:source]))
        }
        {inspect(component), spec}
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

  defp get_alias(component) do
    component
    |> Module.split()
    |> Enum.take(-1)
    |> Module.concat()
    |> inspect()
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

end
